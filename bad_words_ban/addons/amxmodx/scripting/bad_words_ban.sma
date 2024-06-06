/**
 * Credits: Subb98, Mistrick.
 */
#include <amxmodx>
#include <regex>

/*
    1.1 by mx?!:
        * Import FUNCTION_BLOCK_ADVERTISING from chatmanager_addon.sma
    1.2 by mx?!:
        * Ban for domain advertising changed to block message only
*/

#define PLUGIN "Bad Words Ban" // based on code from 'Chat Manager: Addon' version '0.0.4-70' by 'Mistrick'
#define VERSION "1.2"
#define AUTHOR "mx?!, Mistrick"

#pragma semicolon 1

// Comment to disable IP advertising prevention feature, or change value to change ban time (value represents minutes)
#define FUNCTION_BLOCK_ADVERTISING 60
// Ban reason for IP advertising
stock const ADVERT_BAN_REASON[] = "IP advertising";

#if defined FUNCTION_BLOCK_ADVERTISING
#define IP_LEN 22
#define DOMAIN_LEN 32
new const FILE_WHITE_LIST[] = "bad_words_ban_whitelist.ini";
new Array:g_aWhiteListIp;
new Array:g_aWhiteListDomain;
new g_iWhiteListIpSize;
new g_iWhiteListDomainSize;
new Regex:g_rIpPattern;
new Regex:g_rDomainPattern;
#endif // FUNCTION_BLOCK_ADVERTISING

new const FILE_BLACK_LIST[] = "bad_words_ban_blacklist.ini";
new Array:g_aBlackList;
new g_iBlackListSize;

// USE: fb_ban <time> <#userid> <reason>
stock BAN_CMD(id, minutes, const reason[]) server_cmd("fb_ban %i #%i %s", minutes, get_user_userid(id), reason);
// USE: amx_ban <time in mins> <steamID or nickname or #authid or IP> <reason>
//stock BAN_CMD(id, minutes, const reason[]) server_cmd("fb_ban %i #%i ^"%s^"", minutes, get_user_userid(id), reason);

new LOGFILE[] = "ban_words_ban.log";

#define MAX_WORD_LEN 64

enum _:ArrayData {
    ArrayData_Word[MAX_WORD_LEN],
    ArrayData_BanReason[128],
    ArrayData_BanMinutes
};

new bool:g_bBanned[MAX_PLAYERS + 1];

public plugin_precache()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);

    register_clcmd("say", "clcmd_Say");
    register_clcmd("say_team", "clcmd_Say");
}

public plugin_cfg()
{
    LoadBlackList();

    #if defined FUNCTION_BLOCK_ADVERTISING
    new error[2], ret;
    g_rIpPattern = regex_compile("(?:\s*\d+\s*\.){3}", ret, error, charsmax(error));
    g_rDomainPattern = regex_compile("(?:[A-z]){2,}\.(?:[A-z]){2,}", ret, error, charsmax(error));
    LoadWhiteList();
    #endif // FUNCTION_BLOCK_ADVERTISING
}

LoadBlackList()
{
    g_aBlackList = ArrayCreate(ArrayData, 1);

    new file_path[128]; get_localinfo("amxx_configsdir", file_path, charsmax(file_path));
    format(file_path, charsmax(file_path), "%s/%s", file_path, FILE_BLACK_LIST);

    new file = fopen(file_path, "rt");

    if(!file)
    {
        set_fail_state("cant %s '%s'", file_exists(file_path) ? "read" : "find", file_path);
        return;
    }

    new rowstring[512], data[ArrayData], buffer[MAX_WORD_LEN], wchar[MAX_WORD_LEN], minutes[32];
    while(fgets(file, rowstring, charsmax(rowstring)))
    {
        trim(rowstring);

        if(!rowstring[0] || rowstring[0] == ';') continue;

        parse( rowstring,
            buffer, charsmax(buffer),
            data[ArrayData_BanReason], charsmax(data[ArrayData_BanReason]),
            minutes, charsmax(minutes)
        );

        if(strlen(buffer) < 3) continue;

        normalize_string(buffer);
        multibyte_to_wchar(buffer, wchar);
        wchar_tolower_rus(wchar);
        wchar_to_multibyte(wchar, buffer);
        copy(data[ArrayData_Word], charsmax(data[ArrayData_Word]), buffer);

        data[ArrayData_BanMinutes] = str_to_num(minutes);
        ArrayPushArray(g_aBlackList, data);
        g_iBlackListSize++;
    }
    fclose(file);
}

public clcmd_Say(id)
{
    if(!is_user_connected(id))
    {
        return PLUGIN_CONTINUE;
    }

    new message[194];
    read_args(message, charsmax(message));
    remove_quotes(message);
    trim(message);

    static wchar_msg[128], low_message[128], data[ArrayData];

    copy(low_message, charsmax(low_message), message);

    normalize_string(low_message);
    multibyte_to_wchar(low_message, wchar_msg);
    wchar_tolower_rus(wchar_msg);
    wchar_to_multibyte(wchar_msg, low_message);

    for(new i; i < g_iBlackListSize; i++)
    {
        ArrayGetArray(g_aBlackList, i, data);
        while(containi(low_message, data[ArrayData_Word]) > -1)
        {
            if(!g_bBanned[id])
            {
                g_bBanned[id] = true;
                log_to_file(LOGFILE, "%N - '%s' - '%s' - '%s' - %i minutes", id, data[ArrayData_Word], message, data[ArrayData_BanReason], data[ArrayData_BanMinutes]);
                BAN_CMD(id, data[ArrayData_BanMinutes], data[ArrayData_BanReason]);
            }
            return PLUGIN_HANDLED;
        }
    }

    #if defined FUNCTION_BLOCK_ADVERTISING
    static temp[128];
    new ret;
    // TODO: Add white list
    if(regex_match_c(message, g_rIpPattern, ret))
    {
        copy(temp, charsmax(temp), message);
        for(new i, whiteip[IP_LEN]; i < g_iWhiteListIpSize; i++)
        {
            ArrayGetString(g_aWhiteListIp, i, whiteip, charsmax(whiteip));
            while(replace(temp, charsmax(temp), whiteip, "")){}
        }

        if(regex_match_c(temp, g_rIpPattern, ret))
        {
            if(!g_bBanned[id])
            {
                g_bBanned[id] = true;
                log_to_file(LOGFILE, "%N - '%s' - '%s' - %i minutes", id, message, ADVERT_BAN_REASON, FUNCTION_BLOCK_ADVERTISING);
                BAN_CMD(id, FUNCTION_BLOCK_ADVERTISING, ADVERT_BAN_REASON);
            }

            return PLUGIN_HANDLED;
        }
    }
    if(regex_match_c(message, g_rDomainPattern, ret))
    {
        copy(temp, charsmax(temp), message);
        for(new i, whitedomain[DOMAIN_LEN]; i < g_iWhiteListDomainSize; i++)
        {
            ArrayGetString(g_aWhiteListDomain, i, whitedomain, charsmax(whitedomain));
            while(replace(temp, charsmax(temp), whitedomain, "")){}
        }

        if(regex_match_c(temp, g_rDomainPattern, ret))
        {
            //log_to_file(LOGFILE, "%N - '%s'", id, message);
            return PLUGIN_HANDLED;
        }
    }
    #endif // FUNCTION_BLOCK_ADVERTISING

    return PLUGIN_CONTINUE;
}

public client_connect(id)
{
    g_bBanned[id] = false;
}

stock normalize_string(str[])
{
    for (new i; str[i] != EOS; i++)
    {
        str[i] &= 0xFF;
    }
}

stock wchar_tolower_rus(str[])
{
    for (new i; str[i] != EOS; i++)
    {
        if(str[i] == 0x401)
        {
            str[i] = 0x451;
        }
        else if(0x410 <= str[i] <= 0x42F)
        {
            str[i] += 0x20;
        }
    }
}

// Converts MultiByte (UTF-8) to WideChar (UTF-16, UCS-2)
// Supports only 1-byte, 2-byte and 3-byte UTF-8 (unicode chars from 0x0000 to 0xFFFF), because client can't display 2-byte UTF-16
// charsmax(wcszOutput) should be >= strlen(mbszInput)
stock multibyte_to_wchar(const mbszInput[], wcszOutput[]) {
    new nOutputChars = 0;
    for (new n = 0; mbszInput[n] != EOS; n++) {
        if (mbszInput[n] < 0x80) { // 0... 1-byte ASCII
            wcszOutput[nOutputChars] = mbszInput[n];
        } else if ((mbszInput[n] & 0xE0) == 0xC0) { // 110... 2-byte UTF-8
            wcszOutput[nOutputChars] = (mbszInput[n] & 0x1F) << 6; // Upper 5 bits

            if ((mbszInput[n + 1] & 0xC0) == 0x80) { // Is 10... ?
                wcszOutput[nOutputChars] |= mbszInput[++n] & 0x3F; // Lower 6 bits
            } else { // Decode error
                wcszOutput[nOutputChars] = '?';
            }
        } else if ((mbszInput[n] & 0xF0) == 0xE0) { // 1110... 3-byte UTF-8
            wcszOutput[nOutputChars] = (mbszInput[n] & 0xF) << 12; // Upper 4 bits

            if ((mbszInput[n + 1] & 0xC0) == 0x80) { // Is 10... ?
                wcszOutput[nOutputChars] |= (mbszInput[++n] & 0x3F) << 6; // Middle 6 bits

                if ((mbszInput[n + 1] & 0xC0) == 0x80) { // Is 10... ?
                    wcszOutput[nOutputChars] |= mbszInput[++n] & 0x3F; // Lower 6 bits
                } else { // Decode error
                    wcszOutput[nOutputChars] = '?';
                }
            } else { // Decode error
                wcszOutput[nOutputChars] = '?';
            }
        } else { // Decode error
            wcszOutput[nOutputChars] = '?';
        }

        nOutputChars++;
    }
    wcszOutput[nOutputChars] = EOS;
}

// Converts WideChar (UTF-16, UCS-2) to MultiByte (UTF-8)
// Supports only 1-byte UTF-16 (0x0000 to 0xFFFF), because client can't display 2-byte UTF-16
// charsmax(mbszOutput) should be >= wcslen(wcszInput) * 3
stock wchar_to_multibyte(const wcszInput[], mbszOutput[]) {
    new nOutputChars = 0;
    for (new n = 0; wcszInput[n] != EOS; n++) {
        if (wcszInput[n] < 0x80) {
            mbszOutput[nOutputChars++] = wcszInput[n];
        } else if (wcszInput[n] < 0x800) {
            mbszOutput[nOutputChars++] = (wcszInput[n] >> 6) | 0xC0;
            mbszOutput[nOutputChars++] = (wcszInput[n] & 0x3F) | 0x80;
        } else {
            mbszOutput[nOutputChars++] = (wcszInput[n] >> 12) | 0xE0;
            mbszOutput[nOutputChars++] = ((wcszInput[n] >> 6) & 0x3F) | 0x80;
            mbszOutput[nOutputChars++] = (wcszInput[n] & 0x3F) | 0x80;
        }
    }
    mbszOutput[nOutputChars] = EOS;
}

#if defined FUNCTION_BLOCK_ADVERTISING
LoadWhiteList()
{
    g_aWhiteListIp = ArrayCreate(IP_LEN, 1);
    g_aWhiteListDomain = ArrayCreate(DOMAIN_LEN, 1);

    new file_path[128]; get_localinfo("amxx_configsdir", file_path, charsmax(file_path));
    format(file_path, charsmax(file_path), "%s/%s", file_path, FILE_WHITE_LIST);

    new file = fopen(file_path, "rt");

    enum
    {
        READ_NON,
        READ_DOMAIN,
        READ_IP
    };

    if(!file)
    {
        set_fail_state("cant %s '%s'", file_exists(file_path) ? "read" : "find", file_path);
        return;
    }

    new buffer[64], type = READ_NON;
    while(fgets(file, buffer, charsmax(buffer)))
    {
        trim(buffer);
        remove_quotes(buffer);

        if(!buffer[0] || buffer[0] == ';') continue;

        if(contain(buffer, "[ips]") > -1)
        {
            type = READ_IP;
            continue;
        }
        if(contain(buffer, "[domains]") > -1)
        {
            type = READ_DOMAIN;
            continue;
        }

        if(type)
        {
            ArrayPushString(type == READ_IP ? g_aWhiteListIp : g_aWhiteListDomain, buffer);
        }
    }
    fclose(file);

    g_iWhiteListIpSize = ArraySize(g_aWhiteListIp);
    g_iWhiteListDomainSize = ArraySize(g_aWhiteListDomain);
}
#endif // FUNCTION_BLOCK_ADVERTISING
