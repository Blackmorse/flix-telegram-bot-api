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

Example — a simple bot that mirrors messages:

```flix
use TelegramApi.Models.{runWithToken, TelegramBotToken, TelegramUpdate, OutgoingMessage}
use TelegramApi.Handler.sendMessage
use TelegramApi.Receiver.{TelegramUpdatesListener, runWithLongPollingLoop}
use Sys.Env
use Net.Https

def main(): Unit \ { Env, IO, Https } = {
    match Env.getVar("TELEGRAM_BOT_TOKEN") {
        case Some(token) =>
            region rc {
                run {
                    let _ = TelegramUpdatesListener.listenToUpdates();
                    ()
                } with runWithLongPollingLoop(rc, handle(token))
                  with runWithToken(token)
            }
        case None => println("Error: TELEGRAM_BOT_TOKEN environment variable is not set.")
    }
}

def handle(token: String, message: TelegramUpdate): Unit \ { IO } = run {
    match message {
        case TelegramUpdate.TextMessage({chatId, message = text | _}) =>
            let _ = OutgoingMessage.TextMessage({chatId = chatId, text = "You said: ${text}"})
                |> sendMessage;
                // ignoring errors right now
                ()
        case _ => ()
    }
} with runWithToken(token)
  with Https.runWithIO
```

Note: `handle` must be of `IO` type and require a `Region`, because it runs in a
separate thread (uses `spawn` internally).
