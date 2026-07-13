using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Text;

namespace WildBlueIndustries.YouTubeTV
{
    internal static class YtDlpResolver
    {
        internal sealed class ResolveResult
        {
            public bool Success;
            public string StreamUrl;
            public string ErrorMessage;
        }

        public static ResolveResult Resolve(string executable, string sourceUrl, string format, int timeoutSeconds)
        {
            if (string.IsNullOrEmpty(executable))
                return Failure("yt-dlp path is empty.");
            if (string.IsNullOrEmpty(sourceUrl))
                return Failure("YouTube URL is empty.");

            List<string> outputLines = new List<string>();
            StringBuilder errorOutput = new StringBuilder();

            ProcessStartInfo startInfo = new ProcessStartInfo();
            startInfo.FileName = executable;
            startInfo.Arguments = BuildArguments(sourceUrl, format);
            startInfo.UseShellExecute = false;
            startInfo.CreateNoWindow = true;
            startInfo.RedirectStandardOutput = true;
            startInfo.RedirectStandardError = true;
            startInfo.StandardOutputEncoding = Encoding.UTF8;
            startInfo.StandardErrorEncoding = Encoding.UTF8;

            try
            {
                using (Process process = new Process())
                {
                    process.StartInfo = startInfo;
                    process.OutputDataReceived += delegate(object sender, DataReceivedEventArgs args)
                    {
                        if (!string.IsNullOrWhiteSpace(args.Data))
                        {
                            lock (outputLines)
                                outputLines.Add(args.Data.Trim());
                        }
                    };
                    process.ErrorDataReceived += delegate(object sender, DataReceivedEventArgs args)
                    {
                        if (!string.IsNullOrWhiteSpace(args.Data))
                        {
                            lock (errorOutput)
                            {
                                if (errorOutput.Length > 0)
                                    errorOutput.AppendLine();
                                errorOutput.Append(args.Data.Trim());
                            }
                        }
                    };

                    if (!process.Start())
                        return Failure("Could not start yt-dlp.");

                    process.BeginOutputReadLine();
                    process.BeginErrorReadLine();

                    int timeoutMilliseconds = Math.Max(5, timeoutSeconds) * 1000;
                    if (!process.WaitForExit(timeoutMilliseconds))
                    {
                        try
                        {
                            process.Kill();
                        }
                        catch
                        {
                        }
                        return Failure("yt-dlp timed out after " + timeoutSeconds + " seconds.");
                    }

                    process.WaitForExit();
                    if (process.ExitCode != 0)
                    {
                        string details;
                        lock (errorOutput)
                            details = errorOutput.ToString();
                        return Failure(string.IsNullOrEmpty(details)
                            ? "yt-dlp exited with code " + process.ExitCode + "."
                            : "yt-dlp: " + details);
                    }
                }
            }
            catch (Exception ex)
            {
                return Failure("Could not run yt-dlp. Place it in GameData/YouTubeTV/PluginData or configure ytDlpPath. " + ex.Message);
            }

            lock (outputLines)
            {
                for (int index = 0; index < outputLines.Count; index++)
                {
                    Uri streamUri;
                    if (Uri.TryCreate(outputLines[index], UriKind.Absolute, out streamUri)
                        && (streamUri.Scheme == Uri.UriSchemeHttp || streamUri.Scheme == Uri.UriSchemeHttps))
                    {
                        return new ResolveResult
                        {
                            Success = true,
                            StreamUrl = outputLines[index],
                            ErrorMessage = string.Empty
                        };
                    }
                }
            }

            return Failure("yt-dlp returned no directly playable HTTP stream.");
        }

        private static string BuildArguments(string sourceUrl, string format)
        {
            string selectedFormat = string.IsNullOrEmpty(format) ? "best[acodec!=none][vcodec!=none]" : format;
            return "--no-playlist --no-warnings --socket-timeout 15 --format "
                + Quote(selectedFormat)
                + " --get-url -- "
                + Quote(sourceUrl);
        }

        private static string Quote(string value)
        {
            string escaped = (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
            return "\"" + escaped + "\"";
        }

        private static ResolveResult Failure(string message)
        {
            return new ResolveResult
            {
                Success = false,
                StreamUrl = string.Empty,
                ErrorMessage = message
            };
        }
    }
}
