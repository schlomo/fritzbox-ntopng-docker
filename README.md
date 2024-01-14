Fritz!Box traffic analysis with ntopng in Docker
================================================

Set the `FRITZBOX_PASSWORD` environment variable to the password of your Fritz!Box (FB) and run `fritzdump.sh`. After a few seconds a browser window/tab with [NtopNG](https://www.ntop.org/products/traffic-analysis/ntop/) should pop up.

If your FB needs a username, set it in `FRITZBOX_USERNAME`. See `fritzdump.sh` for more variables to tune and for sharing a configuration file with [Fritz!Box Internet Tickets](https://github.com/schlomo/fritzbox-internet-ticket)

If you don't have a username because you are using password-only login, then run the script via `bash -x` and look for the XML snippets. They will show you a username like `fritz1234` that you should use.

You can set `WIRESHARK=1` to start a local [Wireshark](https://www.wireshark.org/) instead of NtopNG.

IPv6
----

It seems like this is mostly working also with IPv6, happy to get PRs with improvements.
