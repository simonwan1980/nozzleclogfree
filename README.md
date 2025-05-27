# NozzleClogFree

<p align="center">
  <img src="https://github.com/simonwan1980/NozzleClogFree/blob/main/icon/icon.png" width="128" height="128" alt="NozzleClogFree Icon">
</p>


## Epson says: print regularly to avoid clogs. But who remembers?


> After every long business trip, I always return to find my Epson color inkjet printer clogged. The only option is to run the built-in cleaning program, which consumes a lot of ink — more ink goes into cleaning than actual printing.  
> Living in Beijing probably doesn’t help — it's very dry here. Epson recommends printing regularly to keep the ink flowing, but I always forget.  
> After my last trip to Italy, the printhead was clogged again. That was the final straw. I decided to solve the problem once and for all.  
> With help from ChatGPT, I wrote a macOS utility called NozzleClogFree. It automatically prints a small test page at scheduled intervals to prevent nozzle clogging.  
> I just came back from another trip to Germany — this time, the printer worked perfectly. No clogs, no wasted ink.  
> Hopefully, it can save you the same trouble.  



**NozzleClogFree** is a small tool to help keep your inkjet printer in good condition by preventing nozzle clogging.

Inkjet printer heads tend to clog if the printer isn’t used for a while. Built-in cleaning functions can clear the clogs, but they waste a lot of ink. Manual cleaning is even more inconvenient and error-prone.

A simple and efficient solution is to print a small page at regular intervals — but it’s easy to forget.

**NozzleClogFree** automates this for you.

- Set your own printing schedule and page, or use the default settings.
- The app will automatically print at the scheduled time.
- It can even wake your computer from sleep to complete the printing (as long as the machine is powered on and connected to the printer).



## Features

- Customizable printing interval and page content
- Wake-from-sleep support (if system is still on and printer is connected)
- Minimal ink usage compared to built-in cleaning processes
- **Smart Mode**: Automatically adjusts the print schedule based on the last 30 days of humidity data



## Permissions

When you first run **NozzleClogFree**, the system will request two permissions. These are essential for the app’s full functionality:

1. **Authorization to install a privileged helper tool**  
   - This allows the app to schedule and perform print jobs **even when your Mac is sleeping** (as long as it is plugged in and the printer is connected).
   - The helper tool is installed using Apple's secure SMJobBless mechanism and runs with system privileges.

2. **Location access**  
   - This is used to **retrieve local humidity data** based on your geographical location. The app uses this data in **Smart Mode** to intelligently adjust the print schedule.
   - No personal or identifiable location data is stored or transmitted — it's only used locally to request weather information from a public weather API.

You can choose to deny either permission, but certain features — like Smart Mode or printing while your Mac is asleep — will be unavailable.



## Download

You can download the latest version of **NozzleClogFree** from the link below:

👉 [NozzleClogFree (.dmg)](https://github.com/simonwan1980/nozzleclogfree/releases/download/v2.9.0/NozzleClogFree.dmg)

