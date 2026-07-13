using System;
using System.IO;

namespace WildBlueIndustries.YouTubeTV
{
    internal static class MediaUrl
    {
        public static string NormalizeInput(string input)
        {
            string value = (input ?? string.Empty).Trim().Trim('"');
            if (string.IsNullOrEmpty(value))
                return string.Empty;

            if (File.Exists(value))
                return new Uri(Path.GetFullPath(value)).AbsoluteUri;

            Uri uri;
            if (Uri.TryCreate(value, UriKind.Absolute, out uri))
            {
                if (uri.IsFile || uri.Scheme == Uri.UriSchemeHttp || uri.Scheme == Uri.UriSchemeHttps)
                    return uri.AbsoluteUri;
            }

            if (LooksLikeYouTubeId(value))
                return "https://www.youtube.com/watch?v=" + value;

            return string.Empty;
        }

        public static bool IsYouTubeUrl(string value)
        {
            Uri uri;
            if (!Uri.TryCreate(value, UriKind.Absolute, out uri))
                return false;

            string host = (uri.Host ?? string.Empty).ToLowerInvariant();
            return host == "youtu.be"
                || host == "youtube.com"
                || host.EndsWith(".youtube.com", StringComparison.Ordinal)
                || host == "youtube-nocookie.com"
                || host.EndsWith(".youtube-nocookie.com", StringComparison.Ordinal);
        }

        private static bool LooksLikeYouTubeId(string value)
        {
            if (value == null || value.Length != 11)
                return false;

            for (int index = 0; index < value.Length; index++)
            {
                char character = value[index];
                if (!char.IsLetterOrDigit(character) && character != '-' && character != '_')
                    return false;
            }

            return true;
        }
    }
}
