
# Toggl Time Tracker

This is an early version so the onboarding process is a little wacky.

1. Visit [your toggl dashboard](https://toggl.com/app/#dashboard)
2. Open Chrome Dev Tools and visit the network panel and search for the summary.json request (may need a page refresh)
3. Find your auth token by clicking on the "Headers" tab and looking for "Request Headers." Copy the long string after `Authorization: Basic ` like here: ![toggl request headers](http://monosnap.com/image/CaNShPKToK2p9fnsyZW0TMkFk3On60.png)
4. Then scroll down to the "Query String Parameters" section and copy values for `user_ids` and `workspace_id`
5. Visit www.kevnk.com/toggl-time-tracker/ and enter your desired monthly earnings, your hourly wage, and your respective toggl credentials that you just copied.

If this doesn't work, you can submit an issue.

Good luck!
