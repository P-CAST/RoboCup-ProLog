using System.Collections;
using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class GameUIRef : MonoBehaviour
{
    public GameObject settingsPanel;
    public TextMeshProUGUI errorMessageText;

    public AudioSource gameMusicAudio;
    public Button settingsButton;
    void Start()
    {
        GameUIManager.Instance.SetUI(this);
    }
}
