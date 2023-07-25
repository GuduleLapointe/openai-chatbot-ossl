//SSL Script

string DEFAULT_CONTEXT = "OpenSimulator Virtual World";
// string OPENAI_API_URL = "https://api.openai.com/v1/engines/davinci/completions";
string OPENAI_API_URL = "https://api.openai.com/v1/chat/completions";

string CONTEXT;
string OPENAI_API_KEY;
string BOT_NAME;
string WAKE_UP_NAME;
integer last_interaction;
string npc = NULL_KEY;
integer initialized = FALSE;
integer listening = TRUE;
list message_log;

error_log(string message) {
    if(message == "") return;
    llOwnerSay("/me debug: " + message);
    // llSay(0, "/me DEBUG: " + message);
}
say(string message) {
    if(message == "") return;
    // llOwnerSay("/me debug: " + message);
    if(npc != "") {
        llSay(0, message);
    } else {
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
    input = llGetSubString(input, 0, 200);
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
    list args = [
        "model", "gpt-3.5-turbo",
        "messages", llList2Json( JSON_ARRAY, messages )
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

    BOT_NAME = llGetObjectName();
    if (llGetAttached() > 0) {
        key avatar = llGetOwner();
        if ( osIsNpc(avatar) ) {
            npc = avatar;
            BOT_NAME = llGetDisplayName(avatar);
        } else {
            npc ="";
            BOT_NAME = llGetDisplayName(avatar) + "'s " + BOT_NAME;
        }
    }

    OPENAI_API_KEY = first_line(get_notecard("~api_key"));
    if( OPENAI_API_KEY == "" ) {
        error_log("Could not read api key, save it in a notecard named ~api_key in the same object as the script");
        return FALSE;
    }

    CONTEXT = get_notecard("~context");
    if(CONTEXT == "") CONTEXT = DEFAULT_CONTEXT;

    CONTEXT = "You are a very funny and familiar assistant designed to help us in this OpenSimulator virtual world. "
    + "If you know the name of the virtual world, rather refer it as its name. "
    + "You are known as " + BOT_NAME + ", so people might call you " + BOT_NAME + ". "
    + "To register an avatar, users need to register on our website, then they will get the details to add the grid on OpenSimulator viewer. "
    + "\n" + CONTEXT;

    error_log("initialize openai api");
    string result = request_api(CONTEXT);
    last_interaction = llGetUnixTime();

    return TRUE;
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
        if(llSubStringIndex(message, "/") == 0) {
            error_log("ignoring slash commands");
            return;
        }
        if ( listening && ( message == "bye" || message == "stop" ) ) {
            // Stop listening if the message is "bye"
            request_api(message + ", thank you for your assistance");
            listening = FALSE;
        } else if ( containsWord( message, BOT_NAME ) ){
            // error_log("got message for me, waking up");
            listening = TRUE;
        } else if (llGetUnixTime() - last_interaction > 120) {
            listening = FALSE;
        }

        if ( listening ) {
            last_interaction = llGetUnixTime();
            // error_log(name + ": " + message);
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
            if(answer != "" ) {
                if( ! initialized ) {
                    initialized = TRUE;
                    llListen( 0, "", NULL_KEY, "" );
                    request_api("Hello, please introduce yourself");
                    return;
                }
                string id = llJsonGetValue(json, ["id"]);
                llSay(0, answer);
                log_message("assistant", answer);
            } else {
                error_log("could not understand the answer: " + body);
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

    attach(key id)
    {
        error_log("attached, reset");
        init_api();
    }

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
