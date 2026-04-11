using System.Collections;
using TMPro;
using UnityEngine;

public class StartButtonAnimator : MonoBehaviour
{
    public TextMeshProUGUI buttonText;

    public float chevronInterval = 0.15f;

    private Coroutine _activeCoroutine;

    void OnEnable()
    {
        _activeCoroutine = StartCoroutine(ChevronWave());
    }

    void OnDisable()
    {
        if (_activeCoroutine != null)
            StopCoroutine(_activeCoroutine);
    }

    IEnumerator ChevronWave()
    {
        string[] frames =
        {
            ">> Start <<",
            " > Start < ",
            "   Start   ",
            " > Start < ",
            ">> Start <<",
        };

        int i = 0;
        while (true)
        {
            buttonText.text = frames[i % frames.Length];
            i++;
            yield return new WaitForSeconds(chevronInterval);
        }
    }
}