# OpenAI Chatbot for OpenSimulator Virtual World

![Version](https://badgen.net/badge/Version/0.1.0/grey) ![Language](https://badgen.net/badge/Language/LSL/blue) ![Requires](https://badgen.net/badge/Requires/OSSL/green) ![License](https://badgen.net/badge/License/AGPLv3/blue)

This script acts as an AI assistant, powered by OpenAI's GPT-3.5 Turbo language model, designed to interact with users in an OpenSimulator virtual world. It listens to chat messages, processes user queries, and responds with appropriate answers.

The script is intended for OpenSimulator and requires the following OSSL functions to be enabled:

- `osGetNotecard()`
- `osIsNpc()`
- `osNpcSay()`

## Usage

1. Include this script in an object in your OpenSimulator virtual world.
2. Create a notecard named "~api_key" in the same object containing the API key to access OpenAI's GPT-3.5 Turbo.
3. Create a notecard named "~context" in the same object containing your world specific context for the assistant.
4. After initialization, the assistant will listen to user messages containing its name and respond accordingly.
5. Users can interact with the assistant by addressing it with its name and asking questions or giving commands.

## Special Commands (to be interpreted and handled by the AI)

The script utilizes the AI to recognize certain requests and instructs the AI to include specific keywords in the answers. These keywords enable the script to process the responses differently.

- `%not_for_me%` will inform the script that the message is not intended for it and the answer should not be processed.
- `%quit%` will instruct the script to end the chat and respond with a farewell message.
- `%sit%` or `%follow%` will instruct the script to answer accordingly, assuming the user typed the commands with the appropriate syntax for a third-party script ("use" and "follow me" for NPC Manager). In a future release, the script will forward the appropriate command to an external script (NPC Manager) which will handle the requested NPC actions.

## Notes

- This script requires an API key to access OpenAI's GPT-3.5 Turbo API. Make sure to keep the key secure and to not include it in the version you might reditribute.
- The script keeps a log of user and assistant interactions, limited to the number of messages set by LOG_LIMIT.
- The assistant will listen to chat messages until 180 seconds of inactivity or a request to end talking, after which it will stop listening until it is called by its name again.
- Any message starting with a slash ("/") is ignored as it may indicate a command for other purposes.
- The assistant's responses are subject to the capabilities and limitations of the GPT-3.5 Turbo language model.
- This version is an early release, and improvements or bug fixes may be needed based on user feedback.

## Feedback and Issues

For feedback or issues, please see [GitHub Repository](https://github.com/GuduleLapointe/openai-chatbot-ossl).
