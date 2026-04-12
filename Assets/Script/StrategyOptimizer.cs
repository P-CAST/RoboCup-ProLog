using System;
using System.Collections;
using UnityEngine;
using UnityEngine.Networking;

[System.Serializable]
public class StrategyParams
{
    public int aggression = 50;
    public int passing_accuracy = 50;
    public int pressing_intensity = 50;
    public int defensive_line = 50;
    public int kick_power = 50;
}

[System.Serializable]
public class OptimizationResultEntry
{
    public float avg_goal_diff;
    public int wins;
    public int aggression;
    public int passing_accuracy;
    public int pressing_intensity;
    public int defensive_line;
    public int kick_power;
}

[System.Serializable]
public class OptimizationResponse
{
    public string status;
    public OptimizationResultEntry[] results;
}

public class StrategyOptimizer : MonoBehaviour
{
    string url = "http://localhost:5000/action";

    public IEnumerator SendSetStrategy(string team, StrategyParams parameters, Action<bool> callback = null)
    {
        string json = JsonUtility.ToJson(new SetStrategyRequest
        {
            action = "set_strategy",
            team = team,
            aggression = parameters.aggression,
            passing_accuracy = parameters.passing_accuracy,
            pressing_intensity = parameters.pressing_intensity,
            defensive_line = parameters.defensive_line,
            kick_power = parameters.kick_power
        });

        UnityWebRequest request = new UnityWebRequest(url, "POST");
        byte[] bodyRaw = System.Text.Encoding.UTF8.GetBytes(json);
        request.uploadHandler = new UploadHandlerRaw(bodyRaw);
        request.downloadHandler = new DownloadHandlerBuffer();
        request.SetRequestHeader("Content-Type", "application/json");

        yield return request.SendWebRequest();

        callback?.Invoke(request.result == UnityWebRequest.Result.Success);
    }

    public IEnumerator SendOptimize(string team, int trials, Action<OptimizationResponse> callback)
    {
        string json = JsonUtility.ToJson(new OptimizeRequest
        {
            action = "optimize",
            team = team,
            trials = trials
        });

        UnityWebRequest request = new UnityWebRequest(url, "POST");
        byte[] bodyRaw = System.Text.Encoding.UTF8.GetBytes(json);
        request.uploadHandler = new UploadHandlerRaw(bodyRaw);
        request.downloadHandler = new DownloadHandlerBuffer();
        request.SetRequestHeader("Content-Type", "application/json");
        request.timeout = 300;

        yield return request.SendWebRequest();

        if (request.result == UnityWebRequest.Result.Success)
        {
            OptimizationResponse response = JsonUtility.FromJson<OptimizationResponse>(request.downloadHandler.text);
            callback?.Invoke(response);
        }
        else
        {
            Debug.LogError("Optimization request failed: " + request.error);
            callback?.Invoke(null);
        }
    }

    [System.Serializable]
    private class SetStrategyRequest
    {
        public string action;
        public string team;
        public int aggression;
        public int passing_accuracy;
        public int pressing_intensity;
        public int defensive_line;
        public int kick_power;
    }

    [System.Serializable]
    private class OptimizeRequest
    {
        public string action;
        public string team;
        public int trials;
    }
}
