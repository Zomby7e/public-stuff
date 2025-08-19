# My own stuff

各個程式/檔案的授權協議，請參考檔案的內容或它的 README.

For the license of each program/file, please refer to its content or its README file.

## User Script

- [Bilibili 自动宽屏 (Bilibili Auto Wide Screen)](user-script/bilibili-auto-wide-screen.user.js) | [Greasy Fork](https://greasyfork.org/zh-CN/scripts/502334-bilibili-%E8%87%AA%E5%8A%A8%E5%AE%BD%E5%B1%8F)
  - Bilibili is a Chinese video sharing platform,this script will add a new "Auto theater mode" Button. Press T to toggle mode. No internationalization.
  - B站是一個中國視訊分享平台，該腳本將添加一個新的「自动宽屏」按鈕。按 T​​ 切換寬螢幕模式。

## Windows Setup
Automates Windows post-install setup: optimizes system settings, removes bloatware and ads, installs open-source tools, and optionally enables virtualization features.  

It uses [Chocolatey](https://chocolatey.org/) for installing clean, open-source alternatives.  

For usage and customization, visit:
https://schneegans.de/windows/unattend-generator/ *(This is not my project)*

- **autounattend.xml**  
  Used for unattended installation of Windows, it will optimize the system and automatically install bundled software including vlc, firefox, etc.
- **init-setup.ps1** 
  It is used for further system optimization after unattended installation, as well as bundled installation. It is already included in the xml file above.

## Windows Management
- Windows right-click menu
- Windows update manager

*Also see: [OFGB](https://github.com/xM4ddy/OFGB) (This is not my project)*