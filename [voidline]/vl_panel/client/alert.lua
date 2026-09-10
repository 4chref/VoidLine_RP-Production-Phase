RegisterNetEvent("SendAlert")
AddEventHandler("SendAlert", function(msg, msg2)
    SendNUIMessage({
        type         = "alert",
        enable       = true,
        issuer       = msg,
        message      = msg2,
        volume       = VLAlertConfig.EAS.Volume,
        duration     = VLAlertConfig.EAS.Duration,
        soundEnabled = VLAlertConfig.EAS.SoundEnabled,
        soundFile    = VLAlertConfig.EAS.SoundFile,
        typeSpeed    = VLAlertConfig.EAS.TypeSpeed,
        sequence     = VLAlertConfig.EAS.Sequence,
        severity     = VLAlertConfig.EAS.Severity
    })
end)
