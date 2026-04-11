using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

public class MainMenuManager : MonoBehaviour
{
    [SerializeField] GameObject instructionsPanel;
    public void StartGame()
    {
        SceneManager.LoadScene("Game");
    }
    public void ToggleInstructionsPanel()
    {
        instructionsPanel.SetActive(!instructionsPanel.activeSelf);
    }
}
