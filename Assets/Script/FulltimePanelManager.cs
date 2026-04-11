using System.Collections;
using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.SceneManagement;

public class FulltimePanelManager : MonoBehaviour
{
    [SerializeField] TextMeshProUGUI teamAScoreText;
    [SerializeField] TextMeshProUGUI teamBScoreText;

    public void setTeamAScore(int score)
    {
        teamAScoreText.text = score.ToString();
    }

    public void setTeamBScore(int score)
    {
        teamBScoreText.text = score.ToString();
    }

    public void changeSceneToMainMenu()
    {
        SceneManager.LoadScene("MainMenu");
    }
    
}
