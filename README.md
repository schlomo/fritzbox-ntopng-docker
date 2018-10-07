Fritz!Box traffic analysis with ntopng in Docker
================================================

Set the `FRITZBOX_PASSWORD` environment variable to the password of your Fritz!Box (FB) and run `fritzdump.sh`. After a few seconds a browser window/tab with [NtopNG](https://www.ntop.org/products/traffic-analysis/ntop/) should pop up.

If your FB needs a username, set it in `FRITZBOX_USER`. See `fritzdump.sh` for more variables to tune.