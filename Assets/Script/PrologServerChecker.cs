using System.Collections;
using TMPro;
using UnityEngine;
using UnityEngine.Networking;

public class PrologServerChecker : MonoBehaviour
{
    [SerializeField] TextMeshProUGUI serverStatusText1;
    [SerializeField] TextMeshProUGUI serverStatusText2;

    string url = "http://localhost:5000/action";
    Coroutine pingCoroutine;

    void Start()
    {
        pingCoroutine = StartCoroutine(PingCheckServerCoroutine());
    }

    IEnumerator PingCheckServerCoroutine()
    {
        while (true)
        {
            yield return StartCoroutine(CheckServerCoroutine()); 
            yield return new WaitForSeconds(1f);
        }
    }

    IEnumerator CheckServerCoroutine()
    {
        string json = "{\"action\":\"step\"}";

        UnityWebRequest request = new UnityWebRequest(url, "POST");
        byte[] bodyRaw = System.Text.Encoding.UTF8.GetBytes(json);

        request.uploadHandler = new UploadHandlerRaw(bodyRaw);
        request.downloadHandler = new DownloadHandlerBuffer();
        request.timeout = 2; 

        request.SetRequestHeader("Content-Type", "application/json");

        yield return request.SendWebRequest();

        // server not running at all
        if (request.result != UnityWebRequest.Result.Success)
        {
            SetStatus("Not Running", Color.red);
            yield break;
        }

        string responseText = request.downloadHandler.text;

        // invalid response
        if (string.IsNullOrEmpty(responseText))
        {
            SetStatus("Not Running", Color.red);
            yield break;
        }

        GameState state = null;

        try
        {
            state = JsonUtility.FromJson<GameState>(responseText);
        }
        catch
        {
            SetStatus("Not Running", Color.red);
            yield break;
        }

        // server running but not initialized
        if (state == null || state.players == null)
        {
            SetStatus("Not Initialized", Color.yellow);
        }
        else
        {
            // fully ready
            SetStatus("Ready", Color.green);
        }
    }

    void SetStatus(string text, Color color)
    {
        serverStatusText1.text = text;
        serverStatusText1.color = color;
        serverStatusText2.text = text;
        serverStatusText2.color = color;
    }
}