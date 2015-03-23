
# Toggl Time Tracker

This is an early version so the onboarding process is a little wacky.

### 1. Visit [your toggl dashboard](https://toggl.com/app/#dashboard)

### 2. Open Chrome Dev Tools 
Visit the Network Panel and search for the `summary.json` request (may need a page refresh)

### 3. Find your auth token
Click on the "Headers" tab and look for "Request Headers." Copy the long string after `Authorization: Basic ` like here: ![toggl request headers](http://monosnap.com/image/CaNShPKToK2p9fnsyZW0TMkFk3On60.png)

### 4. Scroll down to "Query String Parameters"
Copy values for `user_ids` and `workspace_id`

### 5. Visit [kevnk.com/toggl-time-tracker/](http://www.kevnk.com/toggl-time-tracker/) 
Enter your desired monthly earnings, your hourly wage, and your respective toggl credentials that you just copied.


## If it works
It should look something like this:

![screenshot](http://monosnap.com/image/3iGsSAIUrh2085peOxqqE21DludGK1.png)


## Troubleshooting
Feel free to [submit an issue](https://github.com/kevnk/toggl-time-tracker/issues) if you can't get it to work.



