using System;
using System.Collections.Generic;
using System.Text;

namespace CleanMyRoom.Net
{
    /// <summary>
    /// Reassembles newline-delimited UTF-8 messages from arbitrary TCP chunks.
    ///
    /// TCP does not preserve write boundaries: one read may contain half a
    /// message, several messages, or a message split across reads. This class
    /// buffers raw bytes and emits only complete lines.
    ///
    /// It is intentionally free of UnityEngine dependencies so it can be unit
    /// tested outside the editor. Thread safety: Append / Reset are guarded by
    /// an internal lock because a network thread appends while the main thread
    /// may reset the buffer on disconnect.
    /// </summary>
    public sealed class MessageFramer
    {
        private readonly object gate = new object();
        private readonly List<byte> buffer = new List<byte>(8192);
        private readonly int maxMessageBytes;
        private readonly Encoding utf8 = new UTF8Encoding(false);

        /// <summary>Raised with the decoded text of each complete line.</summary>
        public event Action<string> MessageReceived;

        /// <summary>Raised when a line is too large or the buffer grows unbounded.</summary>
        public event Action<string> ProtocolError;

        public MessageFramer(int maxMessageBytes = ProtocolConstants.MaxMessageBytes)
        {
            if (maxMessageBytes <= 0)
            {
                throw new ArgumentOutOfRangeException(nameof(maxMessageBytes));
            }
            this.maxMessageBytes = maxMessageBytes;
        }

        /// <summary>Drop buffered bytes. Call when a connection is lost.</summary>
        public void Reset()
        {
            lock (gate)
            {
                buffer.Clear();
            }
        }

        /// <summary>Append a received byte range and emit every complete line.</summary>
        public void Append(byte[] data, int offset, int count)
        {
            if (data == null)
            {
                return;
            }
            if (offset < 0 || count < 0 || offset + count > data.Length)
            {
                throw new ArgumentOutOfRangeException(nameof(offset));
            }
            if (count == 0)
            {
                return;
            }

            lock (gate)
            {
                for (int i = 0; i < count; i++)
                {
                    buffer.Add(data[offset + i]);
                }
                DrainLocked();
            }
        }

        private void DrainLocked()
        {
            while (true)
            {
                int newline = buffer.IndexOf((byte)'\n');
                if (newline < 0)
                {
                    break;
                }

                int length = newline;
                if (length > 0 && buffer[length - 1] == (byte)'\r')
                {
                    length--; // tolerate CRLF clients
                }

                if (length > maxMessageBytes)
                {
                    buffer.RemoveRange(0, newline + 1);
                    ProtocolError?.Invoke(
                        "Dropped an oversized message (" + length + " bytes, limit " + maxMessageBytes + ").");
                    continue;
                }

                byte[] line = new byte[length];
                buffer.CopyTo(0, line, 0, length);
                buffer.RemoveRange(0, newline + 1);

                string text = utf8.GetString(line);
                if (text.Trim().Length == 0)
                {
                    continue; // ignore empty keep-alive lines
                }

                MessageReceived?.Invoke(text);
            }

            if (buffer.Count > maxMessageBytes)
            {
                int discarded = buffer.Count;
                buffer.Clear();
                ProtocolError?.Invoke(
                    "Dropped " + discarded + " bytes without a newline delimiter (limit " +
                    maxMessageBytes + ").");
            }
        }
    }
}
