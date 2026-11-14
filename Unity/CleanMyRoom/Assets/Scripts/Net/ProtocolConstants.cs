namespace CleanMyRoom.Net
{
    /// <summary>
    /// Shared constants for the MATLAB (server) / Unity (client) TCP protocol.
    /// Keep these values in sync with MATLAB/Communication/+cmr/+net/Protocol.m.
    /// </summary>
    public static class ProtocolConstants
    {
        public const string Version = "1.0";

        public const string DefaultHost = "127.0.0.1";
        public const int DefaultPort = 55001;

        /// <summary>Messages are UTF-8 JSON objects separated by a single LF byte.</summary>
        public const char FrameDelimiter = '\n';

        /// <summary>Hard limit that protects Unity from unbounded partial packets.</summary>
        public const int MaxMessageBytes = 65536;

        public const string TypePing = "PING";
        public const string TypePong = "PONG";
        public const string TypePlaceRequest = "PLACE_REQ";
        public const string TypePlaceResponse = "PLACE_RES";
        public const string TypeActivityResult = "ACTIVITY_RESULT";
        public const string TypeGameProgress = "GAME_PROGRESS";
        public const string TypeError = "ERROR";
    }
}
