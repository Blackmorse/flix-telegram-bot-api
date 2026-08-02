# flix-telegram-bot-api

A minimal implementation of the Telegram Bot API in pure Flix.

Only bare-minimum functionality is implemented so far. If you want to use this
library, you will most likely want to contribute first. Contributions are welcome!

## Implemented

- Long-polling updates fetching in a loop
- Simple text message receiver/parser and sender (with the minimal set of fields)

## Usage

Effects to use: `TelegramUpdatesListener` (runs the long-polling loop with your
handler) and `TelegramBotToken` (passes your bot token).

Messages are sent from the long-polling loop via a `Channel` (Sender, to be precise).
The updates handler receives the `Channel` receiver and processes updates as they
arrive.

Example — a simple bot that mirrors messages:

```flix
use TelegramApi.Models.{runWithToken, TelegramBotToken, TelegramUpdate, OutgoingMessage}
use TelegramApi.Handler.sendMessage
use TelegramApi.Receiver.Listeners.{TelegramUpdatesListener, runWithChannelLongPolling}
use Sys.Env
use Net.Https

def main(): Unit \ { Env, IO, Chan, NonDet }  = {
    match Env.getVar("TELEGRAM_BOT_TOKEN") {
        case Some(token) =>
            run {
              region rc {
                let (sender, receiver) = Channel.buffered(100);
                spawn run {
                    let _ = TelegramUpdatesListener.listenToUpdates();
                    ()
                } with runWithChannelLongPolling(sender)
                  with runWithToken(token)
                  with Https.runWithIO @ rc;
                handleUpdates(receiver)
            }
        } with runWithToken(token)
          with Https.runWithIO
        case None => println("Error: TELEGRAM_BOT_TOKEN environment variable is not set.")
      }
    }

@Tailrec
def handleUpdates(rx: Receiver[TelegramUpdate]): Unit \ { Chan, Https, TelegramBotToken, NonDet } =
   match Channel.recv(rx) {
        case TelegramUpdate.TextMessage({chatId, message = text | _}) =>
            let _ = OutgoingMessage.TextMessage({chatId = chatId, text = "You said: ${text}"})
                |> sendMessage;
            // ignoring errors right now
            handleUpdates(rx)
        case _ => handleUpdates(rx)
   }
```

Note: `handleUpdates` must run in a separate thread (spawned via `spawn`), because
the long-polling loop runs in its own thread and communicates over a `Channel`.
