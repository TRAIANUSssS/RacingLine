class CenterPoint {
    float progress = 0.0f;
    vec3 pos = vec3();
    float speed = 0.0f;
    float spread = 0.0f;
}

class MinePoint {
    float progress = 0.0f;
    vec3 pos = vec3();
    float speed = 0.0f;
}

class AnalysisPoint {
    float progress = 0.0f;
    float deviation = 0.0f;
    float importance = 0.0f;
    float speedDelta = 0.0f;
}

class ProblemZone {
    int rank = 0;
    int index = -1;
    float progress = 0.0f;
    float importance = 0.0f;
    float deviation = 0.0f;
    float spread = 0.0f;
    float centerSpeed = 0.0f;
    float mineSpeed = 0.0f;
    vec3 pos = vec3();
}

class AnalysisBundle {
    string mapName = "";
    string mineRunName = "";
    array<CenterPoint@> centerLine;
    array<MinePoint@> mineLine;
    array<AnalysisPoint@> analysisPoints;
    array<ProblemZone@> problemZones;
}

