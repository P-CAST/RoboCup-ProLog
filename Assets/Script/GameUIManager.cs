using System.Collections;
using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class GameUIManager : MonoBehaviour
{

    // for singleton
    public static GameUIManager Instance { get; private set; }

    private void Awake()
    {
        if (Instance != null && Instance != this)
        {
            Destroy(gameObject); 
            return;
        }

        Instance = this;
        
        DontDestroyOnLoad(gameObject); 
    }  
    private GameUIRef ui;

    public void SetUI(GameUIRef uiRefs)
    {
        ui = uiRefs;

        ui.settingsPanel.SetActive(false);

        ui.settingsButton.onClick.RemoveAllListeners();
        ui.settingsButton.onClick.AddListener(ToggleSettingsPanel);
    }

    public void ToggleSettingsPanel()
    {
        ui.settingsPanel.SetActive(!ui.settingsPanel.activeSelf);
    }

    public void ToggleMusic()
    {
        if (ui.gameMusicAudio.isPlaying)
        {
            ui.gameMusicAudio.Pause();
        } else
        {
            ui.gameMusicAudio.Play();
        }
    }

    public void DisplayErrorMessage(string errorText)
    {
        ui.errorMessageText.text = errorText;
    }

}
