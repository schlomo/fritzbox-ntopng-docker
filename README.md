Fritz!Box traffic analysis with ntopng in Docker
================================================

Set the `FRITZBOX_PASSWORD` environment variable to the password of your Fritz!Box (FB) and run `fritzdump.sh`. After a few seconds a browser window/tab with [NtopNG](https://www.ntop.org/products/traffic-analysis/ntop/) should pop up.

If your FB needs a username, set it in `FRITZBOX_USERNAME`. See `fritzdump.sh` for more variables to tune.

NtopNG in Docker
----------------

The included Docker image [schlomo/ntopng-docker](https://hub.docker.com/r/schlomo/ntopng-docker) can be also used in other scenarios. It is based on many similar ones, I wanted to have one I control and that is up to date.