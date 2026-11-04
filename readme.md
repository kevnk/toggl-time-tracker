# Toggl Time Tracker

One page that reads your Toggl hours for this month and today, then tells you how many more hours to work today to hit a monthly earnings target.

Live page: [www.kevnk.com/toggl-time-tracker/](https://www.kevnk.com/toggl-time-tracker/)

> **Heads up:** this was written in 2015 against Toggl's Reports API v2 at `https://toggl.com/reports/api/v2/` (the `details` and `summary.json` endpoints). Toggl has since moved its app to `track.toggl.com` and released newer API versions, so these requests may no longer work. If they fail, the page shows "Error! Wrong credentials!".

## Setup

You need five values. The page asks for them, in this order, the first time you open it:

1. **Target earnings** for the month, in dollars.
2. **Hourly wage**, in dollars.
3. **Toggl auth token.** The page sends this as `Authorization: Basic <token>`, so it must be the Base64 of `<your API token>:api_token`. Your API token is on your Toggl profile page. To encode it:

   ```sh
   printf '%s' 'YOUR_API_TOKEN:api_token' | base64
   ```

   The original instructions copied this value from the `Authorization: Basic` header of a `summary.json` request in Chrome DevTools (Network panel) on the Toggl dashboard. That gives the same string.
4. **Toggl workspace ID.**
5. **Toggl user ID.**

   For the two IDs, the original instructions copied `workspace_id` and `user_ids` from the query string of that same `summary.json` request.

The page saves these settings in your browser's `localStorage`. Apart from the share link below, it only sends them to Toggl.

## What the numbers mean

Target hours for the month = target earnings ÷ hourly wage. Work days are Monday to Friday. A holiday counts as a work day unless you check it as a vacation day.

| Tab | Shows |
|---|---|
| **Target Today** (first tab, shown by default) | Hours still to work today: today's target average − hours logged today. The page title shows this too, for example `(5.6) Toggl Time Tracker`. |
| **Clock Out** | The current time + Target Today. |
| **Target Today** (third tab) | Today's target average: (target hours − hours logged before today) ÷ work days left, counting today if it's a work day. |
| **Target Tomorrow** | (target hours − hours logged this month) ÷ work days left after today. On the last day of the month, it is target hours ÷ next month's work days. |
| **Current AVG** | Hours logged before today ÷ weekdays worked before today (not counting vacation days). Before the first weekday of the month, it shows the hours logged so far. |
| **Logged Hours** | Hours logged this month. |
| **Target Hours** | Target hours for the month. |

If no work days are left in the month (for example, a weekend at the end of the month), the targets divide by one day instead of zero, so they show all the remaining hours.

## Vacation days

- **Holidays:** the page lists this month's holidays that fall on a weekday as checkboxes. Check one to take it off. The list covers New Year's Day, Martin Luther King Jr. Day, Washington's Birthday, Good Friday, Memorial Day, Independence Day, Labor Day, Columbus Day, Veteran's Day, Thanksgiving and the day after, Christmas Eve, Christmas Day, and New Year's Eve.
- **+ Vacation Day / − Vacation Day:** add or remove a day off that isn't tied to a date. These always count as upcoming, and they stay saved into later months until you remove them.
- **Vacation Days This Month** shows how many vacation days are still ahead.

## Settings menu

Click the cog to change any setting, then click **Save**. Earnings and wage changes update the targets right away. New Toggl credentials take effect on the next refresh or page reload.

## Refreshing

While the tab is in the background, the page refreshes its Toggl data every 2 minutes. When you switch back to the tab, it refreshes if more than 2 minutes have passed since it last refreshed that way.

## Share link

A link with your settings in the query string fills them in on another browser:

```
https://www.kevnk.com/toggl-time-tracker/?e=EARNINGS&w=WAGE&u=USER_ID&s=WORKSPACE_ID&a=AUTH_TOKEN
```

The page saves the values, then reloads without the query string.

- **The link contains your Toggl auth token.** Anyone who has it can read your Toggl data, and opening it sends the token to the web server in the request URL. Share it only with yourself.
- The **Copy Share Url** button builds this link, but it copies through ZeroClipboard, which needs Adobe Flash. Current browsers don't run Flash, so build the link by hand.

## Reset

Open [`reset/`](https://www.kevnk.com/toggl-time-tracker/reset/) to clear your saved settings. It clears everything stored in your browser for `www.kevnk.com`, then sends you back to the page, which asks for your settings again.

## Development

The site is static files. GitHub Pages publishes the `gh-pages` branch, so a push to `gh-pages` deploys. Nothing is compiled on the server.

- Scripts are written in CoffeeScript (`assets/scripts/*.coffee`). The compiled `.js` files sit next to them and are committed.
- Styles are written in Sass (`assets/styles/main.sass`) and compiled to `main.css`. No script for that is set up here.
- Third-party libraries are committed in `bower_components/` (versions in `bower.json`) and `assets/vendor/`.

Dev commands (Node 22.22+, 24.15+, or 26+, which jsdom needs):

```sh
npm install
npm run build   # compile assets/scripts/*.coffee with CoffeeScript 1.7.1
npm test        # unit and page tests
npm run lint    # coffeelint
```

`npm test` loads `index.html` and its scripts in jsdom with a fixed clock and fake Toggl responses. It makes no network calls. It also fails if a committed `.js` file doesn't match its `.coffee` source, so run `npm run build` after editing CoffeeScript.

To preview locally, serve the folder with any static server, for example `python3 -m http.server`. The live page calls Toggl, so a local preview does too. `reset/` redirects to `/toggl-time-tracker/`, or to `/_repos/kevnk/toggl-time-tracker/` when the host is exactly `localhost` (no port), so it won't land on the right page in other local setups.

## Troubleshooting

[Open an issue](https://github.com/kevnk/toggl-time-tracker/issues) if you can't get it to work.
