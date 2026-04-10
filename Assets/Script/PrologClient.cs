using System;
using System.Collections;
using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.Networking;
using UnityEngine.UI;



[System.Serializable]
public class PlayerData
{
    public string name;
    public string team;
    public float x;
    public float y;
}

[System.Serializable]
public class BallData
{
    public float x;
    public float y;
    public float vx;
    public float vy;
}

[System.Serializable]
public class ScoreData
{
    public int teamA;
    public int teamB;
}

[System.Serializable]
public class EventData
{
    public string type;
    public string team;
}

[System.Serializable]
public class GameState
{
    public BallData ball;
    public PlayerData[] players;
    public EventData[] events;
    public ScoreData score;
}

public class PrologClient : MonoBehaviour
{

    [SerializeField] GameObject ballPrefab;
    private GameObject ballObject;
    public GameObject playerPrefab;
    private Dictionary<string, GameObject> playerObjects = new Dictionary<string, GameObject>();
    Dictionary<string, Vector3> targetPositions = new Dictionary<string, Vector3>();
    Vector3 ballTarget; // for smooth unity rendering
    [SerializeField] float secondsToWaitBeforeNextFrame = 0.5f;
    [SerializeField] Toggle interpolationToggle; // frames/positions of players/ball from prolog will be used to render WITHOUT unity smoothing movement rendering

    [SerializeField] Sprite teamACharacter;
    [SerializeField] Sprite teamBCharacter;
    [SerializeField] TextMeshProUGUI scoreText;
    [SerializeField] GameObject LogText;
    string url = "http://localhost:5000/action";



    void Start()
    {
        ResetGame();
        ShowLogText("Game has started!");
        interpolationToggle.isOn = true;
        StartCoroutine(GameLoop());
    }

    IEnumerator GameLoop()
    {
        while(true)
        {
            yield return SendStep();
            yield return new WaitForSeconds(secondsToWaitBeforeNextFrame);
        }
    }

    IEnumerator SendStep()
    {
        string json = "{\"action\":\"step\"}";

        UnityWebRequest request = new UnityWebRequest(url, "POST");
        byte[] bodyRaw = System.Text.Encoding.UTF8.GetBytes(json);

        request.uploadHandler = new UploadHandlerRaw(bodyRaw);
        request.downloadHandler = new DownloadHandlerBuffer();

        request.SetRequestHeader("Content-Type", "application/json");

        yield return request.SendWebRequest();

        string responseText = request.downloadHandler.text;

        Debug.Log(responseText);

        GameState state = JsonUtility.FromJson<GameState>(responseText);

        if (state.events != null)
        {
            foreach (var ev in state.events)
            {
                switch (ev.type)
                {
                    case "goal":
                        Debug.Log("GOAL by Team " + ev.team);
                        ShowLogText("Team " + ev.team +  " scored!");
                        scoreText.text = state.score.teamA + " - " + state.score.teamB;
                        break;
                    case "half_time":
                        ShowLogText("Half-time!");
                        break;
                    case "full_time":
                        ShowLogText("Full-time! Game Over!");
                        break;
                }
                
                if (ev.type == "goal")
                {
                    

                }
            }
        }


        if (state == null)
        {
            Debug.LogError("Error: Prolog Server Not Initiailized!");
            GameUIManager.Instance.DisplayErrorMessage("Error: Prolog Server Not Initiailized!");
        }

        //Debug.Log("Ball X: " + state.ball[0]);

        foreach (var p in state.players)
        {
            if (!playerObjects.ContainsKey(p.name))
            {
                GameObject obj = Instantiate(playerPrefab);

                SpriteRenderer sr = obj.GetComponent<SpriteRenderer>();

                if (p.team == "teamA")
                    //sr.color = Color.blue;
                    sr.sprite = teamACharacter;
                else
                    //sr.color = Color.red;
                    sr.sprite = teamBCharacter;

                playerObjects[p.name] = obj;
            }

            if (!interpolationToggle.isOn) // frames/positions of players/ball from prolog will be used to render WITHOUT unity smoothing rendering
            {
                playerObjects[p.name].transform.position =
                new Vector3(p.x / 20f, p.y / 20f, 0);
            } else  // frames/positions of players/ball from prolog will be used to render WITH unity smoothing rendering
            {
                Vector3 target = new Vector3(p.x / 20f, p.y / 20f, 0);
                targetPositions[p.name] = target;
            }
        
        }

        if (ballObject == null)
        {
            ballObject = Instantiate(ballPrefab);
        }


        //Debug.Log("Ball: " + state.ball[0] + ", " + state.ball[1]);
        Debug.Log("Ball: " + state.ball.x + ", " + state.ball.y);

        if (!interpolationToggle.isOn)
        {
            ballObject.transform.position = new Vector3(state.ball.x / 20f, state.ball.y / 20f, 0);
        } else
        {
            ballTarget = new Vector3(state.ball.x / 20f, state.ball.y / 20f, 0);
        }
        
    }

    private void ShowLogText(string log)
    {
        LogText.GetComponent<Animator>().Play("Logtext", 0, 0f);
        LogText.GetComponentInChildren<TextMeshProUGUI>().text = log;
    }

    // private void ShowGoalUI(string team)
    // {
    //     score
    // }

    // nEw
    public float moveSpeed = 5f;

    void Update()
    {
        foreach (var kvp in playerObjects)
        {
            string name = kvp.Key;
            GameObject obj = kvp.Value;

            if (interpolationToggle.isOn)
            {
                if (targetPositions.ContainsKey(name))
                {
                    obj.transform.position = Vector3.MoveTowards(
                        obj.transform.position,
                        targetPositions[name],
                        moveSpeed * Time.deltaTime
                    );
                }
            }

            
        }

        // Move ball with unity help
        if (interpolationToggle.isOn)
        {
            if (ballObject == null) return;
            ballObject.transform.position = Vector3.MoveTowards(
                ballObject.transform.position,
                ballTarget,
                moveSpeed * Time.deltaTime
            );
        }
        
    }

    public void ResetGame()
    {
        foreach (var obj in playerObjects.Values)
        {
            Destroy(obj);
        }
        Destroy(ballObject);
        playerObjects.Clear();

        scoreText.text = "0 - 0";

        ShowLogText("Game has been reset!");


        //GameUIManager.Instance.ToggleSettingsPanel();
        StartCoroutine(SendReset());
    }

    IEnumerator SendReset()
    {
        string json = "{\"action\":\"reset\"}";

        UnityWebRequest request = new UnityWebRequest(url, "POST");
        byte[] bodyRaw = System.Text.Encoding.UTF8.GetBytes(json);

        request.uploadHandler = new UploadHandlerRaw(bodyRaw);
        request.downloadHandler = new DownloadHandlerBuffer();

        request.SetRequestHeader("Content-Type", "application/json");

        yield return request.SendWebRequest();

        Debug.Log("Game Reset Sent");
    }

    public void speedUpGame()
    {
        if (secondsToWaitBeforeNextFrame <= 0.11f)
        {
            return;
        }
        secondsToWaitBeforeNextFrame-=0.1f;
    }

    public void slowDownGame()
    {
        secondsToWaitBeforeNextFrame+=0.1f;
    }
}