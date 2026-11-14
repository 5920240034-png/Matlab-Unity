using System;
using System.Globalization;
using System.Text;
using UnityEngine;

namespace CleanMyRoom.Net
{
    /// <summary>
    /// Minimal JSON codec for protocol messages.
    ///
    /// Decoding uses Unity's JsonUtility: it ignores unknown fields and fills
    /// missing fields with defaults, which suits this flat protocol. Encoding
    /// is done by hand so outgoing requests contain only the fields the
    /// server expects and numbers always use the invariant culture.
    ///
    /// This class never validates gameplay answers. It only moves data.
    /// </summary>
    public static class JsonCodec
    {
        public static bool TryDecode(string text, out WireMessage message, out string error)
        {
            message = null;
            error = string.Empty;

            if (string.IsNullOrWhiteSpace(text))
            {
                error = "Empty message.";
                return false;
            }

            try
            {
                message = JsonUtility.FromJson<WireMessage>(text);
            }
            catch (Exception ex)
            {
                error = "Malformed JSON: " + ex.Message;
                return false;
            }

            if (message == null)
            {
                error = "Top-level JSON value is not an object.";
                return false;
            }

            if (string.IsNullOrEmpty(message.type))
            {
                error = "Missing or invalid required field 'type'.";
                message = null;
                return false;
            }

            return true;
        }

        /// <summary>Build a PING request line (without the trailing newline).</summary>
        public static string EncodePing(string requestId)
        {
            return "{\"type\":\"" + ProtocolConstants.TypePing + "\"," +
                   "\"requestId\":\"" + Escape(requestId) + "\"}";
        }

        /// <summary>Build a PLACE_REQ line (without the trailing newline).</summary>
        public static string EncodePlaceRequest(
            string requestId,
            string activityId,
            string objectId,
            string targetId,
            float normalizedX,
            float normalizedY)
        {
            return "{\"type\":\"" + ProtocolConstants.TypePlaceRequest + "\"," +
                   "\"requestId\":\"" + Escape(requestId) + "\"," +
                   "\"activity\":\"" + Escape(activityId) + "\"," +
                   "\"objectId\":\"" + Escape(objectId) + "\"," +
                   "\"targetId\":\"" + Escape(targetId) + "\"," +
                   "\"position\":{\"x\":" + Number(normalizedX) +
                   ",\"y\":" + Number(normalizedY) + "}}";
        }

        private static string Number(float value)
        {
            return value.ToString("R", CultureInfo.InvariantCulture);
        }

        private static string Escape(string value)
        {
            if (string.IsNullOrEmpty(value))
            {
                return string.Empty;
            }

            StringBuilder builder = new StringBuilder(value.Length + 8);
            foreach (char character in value)
            {
                switch (character)
                {
                    case '"': builder.Append("\\\""); break;
                    case '\\': builder.Append("\\\\"); break;
                    case '\b': builder.Append("\\b"); break;
                    case '\f': builder.Append("\\f"); break;
                    case '\n': builder.Append("\\n"); break;
                    case '\r': builder.Append("\\r"); break;
                    case '\t': builder.Append("\\t"); break;
                    default:
                        if (character < ' ')
                        {
                            builder.Append("\\u");
                            builder.Append(((int)character).ToString("x4", CultureInfo.InvariantCulture));
                        }
                        else
                        {
                            builder.Append(character);
                        }
                        break;
                }
            }
            return builder.ToString();
        }
    }
}
