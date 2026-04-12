using System.Collections;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class StrategyPanelUI : MonoBehaviour
{
    [Header("Panel")]
    [SerializeField] GameObject strategyPanel;

    [Header("Team Selection")]
    [SerializeField] TMP_Dropdown teamDropdown;

    [Header("Sliders")]
    [SerializeField] Slider aggressionSlider;
    [SerializeField] Slider passingAccuracySlider;
    [SerializeField] Slider pressingIntensitySlider;
    [SerializeField] Slider defensiveLineSlider;
    [SerializeField] Slider kickPowerSlider;

    [Header("Slider Value Labels")]
    [SerializeField] TextMeshProUGUI aggressionValue;
    [SerializeField] TextMeshProUGUI passingAccuracyValue;
    [SerializeField] TextMeshProUGUI pressingIntensityValue;
    [SerializeField] TextMeshProUGUI defensiveLineValue;
    [SerializeField] TextMeshProUGUI kickPowerValue;

    [Header("Buttons")]
    [SerializeField] Button optimizeButton;
    [SerializeField] Button applyButton;
    [SerializeField] Button applyBestButton;

    [Header("Results")]
    [SerializeField] TextMeshProUGUI resultsText;
    [SerializeField] TextMeshProUGUI statusText;

    [Header("References")]
    [SerializeField] StrategyOptimizer optimizer;
    [SerializeField] PrologClient prologClient;

    private OptimizationResultEntry bestResult;
    private bool wasRunningBeforeOpen = false;

    void Start()
    {
        strategyPanel.SetActive(false);

        SetupSlider(aggressionSlider, aggressionValue);
        SetupSlider(passingAccuracySlider, passingAccuracyValue);
        SetupSlider(pressingIntensitySlider, pressingIntensityValue);
        SetupSlider(defensiveLineSlider, defensiveLineValue);
        SetupSlider(kickPowerSlider, kickPowerValue);

        optimizeButton.onClick.AddListener(OnOptimize);
        applyButton.onClick.AddListener(OnApplyCurrent);
        applyBestButton.onClick.AddListener(OnApplyBest);

        applyBestButton.interactable = false;
        resultsText.text = "";
        statusText.text = "";
    }

    void SetupSlider(Slider slider, TextMeshProUGUI label)
    {
        slider.minValue = 0;
        slider.maxValue = 100;
        slider.value = 50;
        slider.wholeNumbers = true;
        label.text = "50";
        slider.onValueChanged.AddListener((val) => label.text = ((int)val).ToString());
    }

    public void TogglePanel()
    {
        bool opening = !strategyPanel.activeSelf;
        strategyPanel.SetActive(opening);

        if (opening)
        {
            wasRunningBeforeOpen = !prologClient.IsPaused();
            prologClient.PauseGame();
        }
        else
        {
            if (wasRunningBeforeOpen)
                prologClient.ResumeGame();
        }
    }

    string GetSelectedTeam()
    {
        return teamDropdown.value == 0 ? "teamA" : "teamB";
    }

    StrategyParams GetCurrentParams()
    {
        return new StrategyParams
        {
            aggression = (int)aggressionSlider.value,
            passing_accuracy = (int)passingAccuracySlider.value,
            pressing_intensity = (int)pressingIntensitySlider.value,
            defensive_line = (int)defensiveLineSlider.value,
            kick_power = (int)kickPowerSlider.value
        };
    }

    void OnApplyCurrent()
    {
        string team = GetSelectedTeam();
        StrategyParams parameters = GetCurrentParams();
        StartCoroutine(optimizer.SendSetStrategy(team, parameters, (success) =>
        {
            statusText.text = success ? "Strategy applied!" : "Failed to apply strategy.";
        }));
    }

    void OnOptimize()
    {
        string team = GetSelectedTeam();
        statusText.text = "Optimizing... This may take a moment.";
        optimizeButton.interactable = false;
        resultsText.text = "";
        applyBestButton.interactable = false;

        StartCoroutine(optimizer.SendOptimize(team, 1, (response) =>
        {
            optimizeButton.interactable = true;

            if (response == null || response.results == null || response.results.Length == 0)
            {
                statusText.text = "Optimization failed.";
                return;
            }

            bestResult = response.results[0];
            statusText.text = "Optimization complete!";

            string resultStr = "Top Strategies:\n";
            for (int i = 0; i < response.results.Length; i++)
            {
                var r = response.results[i];
                resultStr += $"\n#{i + 1}: Aggr={r.aggression} Pass={r.passing_accuracy} " +
                             $"Press={r.pressing_intensity} Def={r.defensive_line} Kick={r.kick_power}" +
                             $"\n    Goal Diff: {r.avg_goal_diff:+0.0;-0.0;0} | Wins: {r.wins}";
            }
            resultsText.text = resultStr;
            applyBestButton.interactable = true;
        }));
    }

    void OnApplyBest()
    {
        if (bestResult == null) return;

        string team = GetSelectedTeam();
        StrategyParams parameters = new StrategyParams
        {
            aggression = bestResult.aggression,
            passing_accuracy = bestResult.passing_accuracy,
            pressing_intensity = bestResult.pressing_intensity,
            defensive_line = bestResult.defensive_line,
            kick_power = bestResult.kick_power
        };

        aggressionSlider.value = parameters.aggression;
        passingAccuracySlider.value = parameters.passing_accuracy;
        pressingIntensitySlider.value = parameters.pressing_intensity;
        defensiveLineSlider.value = parameters.defensive_line;
        kickPowerSlider.value = parameters.kick_power;

        StartCoroutine(optimizer.SendSetStrategy(team, parameters, (success) =>
        {
            statusText.text = success ? "Best strategy applied!" : "Failed to apply strategy.";
        }));
    }
}
