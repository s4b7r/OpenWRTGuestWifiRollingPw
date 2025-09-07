# OpenWRTGuestWifiPasswordChanger

Some scripts to change a wifi's, e.g. guest wifi, password aka PSK on OpenWrt via uci, e.g. every night (or what you like), and to display the random password via CGI in browser with QR-Code.

This does not use a random key but generates one based on the current time (some timestamp), combines that with a salt for "security", and uses the hash as the wifi PSK.

## Dependencies

Install 'qrencode' package.
```
opkg update
opkg install qrencode
```

## Copy Files

Move script to /root. Move CGI script to /www/cgi-bin/

```
mv scripts/ChangeGuestWifiPW.sh /root
mv cgi/guestpw /www/cgi-bin/
```

## make files executable

```
chmod +x /root/ChangeGuestWifiPW.sh
chmod +x /www/cgi-bin/guestpw
```

## Add Cronjob

For example, add a cronjob changing the PSK every night at 4 a.m.

```
0 4 * * * /root/ChangeGuestWifiPW.sh
```

Or (approx.) every third day 3:30 am

```
3 3 */3 * * /root/ChangeGuestWifiPw.sh
```

## Also

Finally, modify the SSID of your guest wifi and salt in the ChangeGuestWifiPW.sh script and access your guest PSK page by http(s)://xxx.xxx.xxx.xxx/cgi-bin/guestpw
