using System;

namespace CleanMyRoom.Net
{
    /// <summary>Normalized activity-space point sent with a placement request.</summary>
    [Serializable]
    public sealed class WirePosition
    {
        public float x;
        public float y;
    }

    /// <summary>
    /// Flat representation of every field the protocol can carry.
    /// Unity uses it only to *display* what MATLAB decided; it contains no
    /// validation logic. Missing JSON fields simply keep their default value.
    /// </summary>
    [Serializable]
    public sealed class WireMessage
    {
        public string type;
        public string requestId;
        public string activity;
        public string objectId;
        public string targetId;
        public WirePosition position;

        // PLACE_RES
        public bool valid;
        public bool correct;
        public int score;

        // ACTIVITY_RESULT
        public bool completed;
        public int stars;

        // GAME_PROGRESS
        public bool gameCompleted;
        public string[] completedActivities;

        // ERROR
        public string code;

        // PONG
        public string status;

        // Human readable text supplied by MATLAB (informational only).
        public string message;

        public bool IsType(string expected)
        {
            return string.Equals(type, expected, StringComparison.Ordinal);
        }
    }
}
