# Capturing the write sequence

The mouse accepts writes from this app and then discards them, so the framing it
expects on write differs from the way settings are read. A USB capture of the
Windows software performing a real write settles it — the capture contains the
literal byte sequence, including any command bytes and checksum this app is not
producing.

This is a passive recording. Nothing is sent to the mouse by capturing.

## On a Windows machine

1. Install [Wireshark](https://www.wireshark.org/download.html) and tick
   **USBPcap** during setup (it is an optional component of the installer).
2. Plug the Model O in and install the Glorious software, but **do not open it
   yet**.
3. Launch Wireshark as Administrator and start a capture on the **USBPcap**
   interface the mouse is attached to. If several are listed, pick the one whose
   traffic moves when you move the mouse.
4. Open the Glorious software.
5. Change **exactly one** setting — polling rate to 125 Hz is ideal, because it
   is also a setting this app has not located yet — and click **Apply**.
6. Stop the capture.

Keep it short. Ten seconds of capture is plenty, and a smaller file is easier to
work with.

## Export it

In Wireshark:

1. Narrow to the mouse with a display filter, replacing the address with the
   one from your capture:

   ```
   usb.device_address == 5 && usb.transfer_type == 0x02
   ```

   Not required, but it keeps the export small.
2. **File > Export Packet Dissections > As JSON**
3. If you filtered, choose **All packets / Displayed**.

Send the resulting `.json`. The raw `.pcapng` works too, but the JSON export is
what the analyser reads directly.

## Analyse it

```bash
swift run gloriousctl-capture capture.json analysis.txt
```

The output lists every feature-report transfer on reports `0x04` and `0x05`,
then reports:

- **Command bytes on report `0x05`** the app does not currently use — the likely
  write-enable and commit steps.
- **What brackets each block write** — which command precedes it and which
  follows.
- **How a written block differs from the one just read** — a byte that changes
  on write but reads back as zero is a length, sequence number or checksum, and
  is the most likely reason writes are being discarded.

## Why not just try command bytes

These Sinowealth controllers expose firmware-flash entry over this same HID
interface; that is how community firmware-dumping tools work on them. An
unrecognised command byte can put the mouse into bootloader mode or trigger an
erase. Guessing is not worth the risk when a capture answers it exactly.
