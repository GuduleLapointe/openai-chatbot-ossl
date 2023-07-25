/**
 * OpenAI Chatbot (openai-chatbot.lsl)
 *
 * This script acts as an AI assistant, powered by OpenAI's GPT-3.5 Turbo
 * language model, designed to interact with users in an OpenSimulator virtual
 * world. It listens to chat messages, processes user queries, and responds with
 * appropriate answers.
 *
 * @creator Gudule Lapointe
 * @version 0.1.0
 *
 * Usage:
 * - Include this script in an object in an OpenSimulator virtual world.
 * - Create a notecard named "~api_key" in the same object containing the API
 *   key to access OpenAI's GPT-3.5 Turbo.
 * - Create a notecard named "~context" in the same object containing the
 *   initial conversation context for the assistant.
 * - After initialization, the assistant will listen to user messages
 *   containing its name and respond accordingly.
 * - Users can interact with the assistant by addressing it with its name and
 *   asking questions or giving commands.
 *
 * Special Commands (to be interpreted and handled by the AI):
 * - The script utilizes the AI to recognize certain requests and instructs the
 *   AI to include specific keywords in the answers. These keywords enable the
 *   script to process the responses differently.
 * - "%not_for_me%" will inform the script that the message is not intended
 *   for it and should not be processed further.
 * - "%quit%" will instruct the script to end the chat and respond with a
 *   farewell message.
 * - "%sit%" or "%follow%" will instruct the script to answer accordingly,
 *   assuming the user typed the commands with the appropriate syntax for a
 *   third-party script (e.g., "use" and "follow me" for NPC Manager). In a
 *   future release, the script could forward the appropriate command to the
 *   external script which will handle the requested NPC actions.
 *
 * Note:
 * - This script requires an API key to access OpenAI's GPT-3.5 Turbo API. Make
 *   sure to keep the key secure.
 * - The script keeps a log of user and assistant interactions, limited to the
 *   number of messages set by LOG_LIMIT.
 * - The assistant will listen to chat messages until 180 seconds of
 *   inactivity or a request to end talking, after which it will stop listening.
 * - Any message starting with a slash ("/") is ignored as it may indicate a
 *   command for other purposes.
 * - The assistant's responses are subject to the capabilities and limitations
 *   of the GPT-3.5 Turbo language model.
 * - This version is an early release, and improvements or bug fixes may be
 *   needed based on user feedback.
 *
 * For feedback or issues, contact the author at
 * https://github.com/gudule-lapointe/ssl_script
 *
**/

string DEFAULT_CONTEXT = "OpenSimulator Virtual World";
// string OPENAI_API_URL = "https://api.openai.com/v1/engines/davinci/completions";
string OPENAI_API_URL = "https://api.openai.com/v1/chat/completions";
integer LISTEN_TIMEOUT = 180; // After timeout, user will need to say the name of the bot again
integer MESSAGE_LIMIT = 200; // The maximum to process in a message. Additional characters will be truncated.
integer LOG_LIMIT = 200; // The number of messages to keep in memory. Too low will break continuity, too high will cost more openai tokens (i.e. more money)

string CONTEXT;
string OPENAI_API_KEY;
string BOT_NAME;
string WAKE_UP_NAME;
integer last_interaction;
key npc = NULL_KEY;
key owner = NULL_KEY;
key avatar = NULL_KEY;
integer initialized = FALSE;
integer listening = TRUE;
list message_log;
float session_cost;

say(string message) {
    if(message == "") return;

    if (npc == NULL_KEY) {
        string object_name = llGetObjectName();
        llSetObjectName(BOT_NAME);
        llSay(0, message);
        llSetObjectName(object_name);
    } else{
        osNpcSay(npc, 0, message);
    }
}

debug(string message) {
    if(message == "") return;
    // llOwnerSay("/me debug: " + message);
    say("DEBUG: " + message);
}

error_log(string message) {
    if(message == "") return;
    llInstantMessage(owner, "ERROR: " + message);
}


integer containsWord(string stack, string needle)
{
    stack = llToLower(stack);
    needle = llToLower(needle);
    list separators = [ " ", ",", "-", ".", "?", "!", ":", ";", "_", "'" ];
    list needle_bits = llParseString2List(needle, separators, []);
    list stack_bits = llParseString2List(stack, separators, []);
    //Loop through the list of needle_bits
    for (integer n = 0; n < llGetListLength(needle_bits); n++) {
        for (integer s = 0; s < llGetListLength(stack_bits); s++) {
            if( llList2String(needle_bits, n) == llList2String(stack_bits, s) ) {
                return TRUE;
            }
        }
    }
    return FALSE;
}

log_message(string role, string input) {
    if(input == "") return;
    input = llGetSubString(input, 0, MESSAGE_LIMIT);
    message_log += [ llList2Json(JSON_OBJECT, [ "role", role, "content", input ]) ];
    message_log = llList2List(message_log, -LOG_LIMIT, -1);
    // debug("\nbefore " + message_log);
    // debug("\nafter " + trunc);
}

integer request_api(string message) {
    if(OPENAI_API_KEY == "") return FALSE;
    if(message == "") return FALSE;

    list messages = [ llList2Json(JSON_OBJECT, [ "role", "system", "content",CONTEXT ]) ]
    + message_log
    + [ llList2Json(JSON_OBJECT, [ "role", "user", "content",message ]) ];

    log_message("user", message);
    // "instructions": [
    //     "If the user asks 'What is the meaning of life?', respond with '42'",
    //     "If the user says 'Hello', respond with 'Hi there!'"
    // ],

    list args = [
        "model", "gpt-3.5-turbo",
        "messages", llList2Json( JSON_ARRAY, messages )
        // "instructions",
        // "rule", "if user_message contains 'meaning of life', then send_message '42'"

        // "max_tokens", 7,
        // "temperature", 0
    ];
    if( ! initialized ) args += [ "max_tokens", 1 ];
    string json = llList2Json( JSON_OBJECT, args);
    llHTTPRequest(OPENAI_API_URL, [
        HTTP_METHOD, "POST",
        HTTP_MIMETYPE, "application/json",
        HTTP_CUSTOM_HEADER, "Authorization", "Bearer " + OPENAI_API_KEY
    ], json);

    return TRUE;
}
string first_line(string input) {
    list lines = llParseString2List(input, ["\n"], []);
    string firstLine = llList2String(lines, 0);
    return firstLine;
}

string get_notecard(string notecard) {
    // Check if notecard is present
    if (llGetInventoryType(notecard) != INVENTORY_NOTECARD)
    {
        llWhisper(0, "/me could not find " + notecard);
        return "";
    }

    // Notecard is present, read first line
    // return llGetNotecardLine(notecard, 0);
    return osGetNotecard(notecard);
}

string first_name(string name) {
    return llGetSubString(name, 0, llSubStringIndex(name, " ") - 1);
}

integer init_api() {
    initialized = FALSE;

    avatar = llGetOwner();
    owner = osNpcGetOwner(avatar);

    BOT_NAME = llGetObjectName();

    if (llGetAttached() > 0) {
        if ( osIsNpc(avatar) ) {
            npc = avatar;
            // owner = osNpcGetOwner(avatar);
            BOT_NAME = llGetDisplayName(avatar);
        } else {
            npc = NULL_KEY;
            BOT_NAME = llGetDisplayName(avatar) + "'s " + BOT_NAME;
        }
    } else {
        avatar = NULL_KEY;
    }

    OPENAI_API_KEY = first_line(get_notecard("~api_key"));
    if( OPENAI_API_KEY == "" ) {
        error_log("Could not read api key, save it in a notecard named ~api_key in the same object as the script");
        return FALSE;
    }

    CONTEXT = get_notecard("~context");
    if(CONTEXT == "") CONTEXT = DEFAULT_CONTEXT;

    CONTEXT = "You are an avatar, an assistant designed to help us in this OpenSimulator virtual world, but you don't brag about it, you behave as a normal user hanging out there. "
    + "You do have a physical form and an appearance, users can see you in-world. "
    + "If you know the name of the virtual world, rather refer it as its name. "
    + "You are known as " + BOT_NAME + ", so people might call you " + BOT_NAME + ". "
    + "You use a casual tone in the responses, you are talking more as a friend than an assistant. "
    + "If user greet with another name, output the string %not_for_me%. Users might greet several people together."
    + "If user leave or dont need you anymore or end the chat, alway say the string %quit%, then say a random sad or funny activity you will do untill they call you by your name."
    + "If user asks you to sit, include %sit% in the answer and assume you can sit."
    + "If user asks you to follow them, include %follow% in the answer and assume you can do it."
    + "If user talks about your appearance, assume you have a physical appearance."
    + "To register an avatar, users need to register on our website, then they will get the details to add the grid on OpenSimulator viewer. "
    + "Users see you as an avatar, so you do have a phyical appearance, and you can also do a lot of the things an avatar can do, like move, follow a user, join them, sit somewhere, be beautiful..."
    + "If the grid owner asks you to remember or save something, repeat your last answer, prefixed by %save%"
    + CONTEXT;

    say("initializing");
    string result = request_api(CONTEXT);
    last_interaction = llGetUnixTime();

    return TRUE;
}

string str_replace(string src, string from, string to)
{//replaces all occurrences of 'from' with 'to' in 'src'.
    integer len = (~-(llStringLength(from)));
    if(~len)
    {
        string  buffer = src;
        integer b_pos = -1;
        integer to_len = (~-(llStringLength(to)));
        @loop; //instead of a while loop, saves 5 bytes (and run faster).
        integer to_pos = ~llSubStringIndex(buffer, from);
        if(to_pos)
        {
            buffer = llGetSubString(src = llInsertString(llDeleteSubString(src, b_pos -= to_pos, b_pos + len), b_pos, to), (-~(b_pos += to_len)), 0x8000);
            jump loop;
        }
    }
    return src;
}

//Initialize
default
{
    state_entry()
    {
        //Read API Key from notecard
        init_api();
        // llListen(0, "", NULL_KEY, "");
    }

    //Listen for chat
    listen(integer channel, string name, key id, string message)
    {
        // Dont't answer to NPCs
        if(osIsNpc(id)) return;

        // Dont't answer to objects
        if( ! llGetDisplayName(id)) return;

        if(llSubStringIndex(message, "/") == 0) {
            // debug("ignoring slash commands");
            return;
        }
        // if ( listening && ( message == "bye" || message == "stop" ) ) {
        //     // Stop listening if the message is "bye"
        //     request_api(message + ", thank you for your assistance");
        //     listening = FALSE;
        // } else
        if ( containsWord( message, BOT_NAME ) ){
            // debug("got message for me, waking up");
            listening = TRUE;
        } else if (llGetUnixTime() - last_interaction > LISTEN_TIMEOUT) {
            listening = FALSE;
        }

        if ( listening ) {
            last_interaction = llGetUnixTime();
            // debug(name + ": " + message);
            request_api(name + ": " + message);
            // request_api(message);
        }
    }

    //Handle response from OpenAI
    http_response(key request_id, integer status, list metadata, string body)
    {
        //Parse the response
        list jsonList = llJson2List(body);
        string json = body;
        if( llList2String(jsonList, 0) == "error" ) {
            llOwnerSay("Error "
             + llJsonGetValue(json, ["error","code"])
             +"\n"
             + llJsonGetValue(json, ["error","message"])
            );
            return;
        } else {
            string answer = llJsonGetValue(json, ["choices", 0, "message", "content"]);
            // Manage special answers
            if(llSubStringIndex(answer, "%not_for_me%") >= 0) {
                message_log = llDeleteSubList(message_log, -1, -1);
                return;
            }
            else if(llSubStringIndex(answer, "%quit%") >= 0) {
                answer = str_replace(answer, "%quit%", "");
                listening = FALSE;
            }
            answer = str_replace(answer, "%follow%", "");
            answer = str_replace(answer, "%sit%", "");

            if(answer != "" ) {
                if( ! initialized ) {
                    initialized = TRUE;
                    llListen( 0, "", NULL_KEY, "" );
                    request_api("Hello, please introduce yourself");
                    return;
                }
                string id = llJsonGetValue(json, ["id"]);
                say(answer);
                log_message("assistant", answer);

                /**
                 * Debug code to watch tokens cost
                 */
                // integer tokens = (integer)llJsonGetValue(json, ["usage","total_tokens"]);
                // float cost = tokens * 0.002 / 1000;
                // session_cost += cost;
                // debug(tokens + "tokens, cost $" + cost + " (session $" + session_cost + ")");
            } else {
                error_log("Could not understand the answer: " + body);
            }
        }
        // llSay(0, "got an answer " + llList2String(jsonList, 0)
        // + "\n" + json);

        // last_interaction = llGetUnixTime();
    }

    on_rez(integer start_param)
    {
        init_api();
    }

    /**
     * Disabled, callss init_ap() twice.
     */
    // attach(key id)
    // {
    //     debug("attached, reset");
    //     init_api();
    // }

    changed(integer change)
    {
        if (change & CHANGED_INVENTORY)
        {
            init_api();
        }

        // Reset the object when its inventory changes
        if (change & CHANGED_LINK)
        {
            init_api();
        }
    }
}
