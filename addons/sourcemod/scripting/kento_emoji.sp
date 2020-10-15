#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <kento_csgocolors>

#pragma newdecls required

#define MAX_EMOJI 1000

char Configfile[1024], 
	emojiName[MAX_EMOJI + 1][256], 
	emojiFile[MAX_EMOJI + 1][1024],
	emojiFlag[MAX_EMOJI + 1][AdminFlags_TOTAL];

int emojiCount,
	spirit[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE,...};

ConVar Cvar_Duration;
float duration;

public Plugin myinfo =
{
	name = "[CS:GO] Emoji",
	author = "Kento",
	version = "1.1",
	description = "Show me your love.",
	url = "http://steamcommunity.com/id/kentomatoryoshika/"
};

public void OnPluginStart() 
{
	RegConsoleCmd("sm_emoji", Command_Emoji, "Use emoji");

	Cvar_Duration = CreateConVar("sm_emoji_duration", "5.0", "Emoji display duration", FCVAR_NOTIFY, true, 0.0);
	Cvar_Duration.AddChangeHook(OnConVarChanged);

	AutoExecConfig(true, "kento.emoji");

	LoadTranslations("kento.emoji.phrases");
}

public void OnConfigsExecuted()
{
	duration = Cvar_Duration.FloatValue;
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar == Cvar_Duration)	duration = Cvar_Duration.FloatValue;
}

public void OnMapStart() 
{
	LoadConfig();
}

void LoadConfig()
{
	BuildPath(Path_SM, Configfile, sizeof(Configfile), "configs/kento_emoji.cfg");
	
	if(!FileExists(Configfile))
		SetFailState("Can not find config file \"%s\"!", Configfile);
	
	KeyValues kv = CreateKeyValues("emoji");
	kv.ImportFromFile(Configfile);
	
	// Read Config
	if(kv.GotoFirstSubKey())
	{
		char name[1024];
		char file[1024];
		char flag[AdminFlags_TOTAL];

		emojiCount = 1;

		do
		{
			kv.GetSectionName(name, sizeof(name));
			kv.GetString("file", file, sizeof(file));
			kv.GetString("flag", flag, sizeof(flag), "");
			
			strcopy(emojiName[emojiCount], sizeof(emojiName[]), name);
			strcopy(emojiFile[emojiCount], sizeof(emojiFile[]), file);
			strcopy(emojiFlag[emojiCount], sizeof(emojiFlag[]), flag);
			
			char vmtpath[1024];
			Format(vmtpath, sizeof(vmtpath), "materials/%s.vmt", emojiFile[emojiCount]);
			char vtfpath[1024];
			Format(vtfpath, sizeof(vtfpath), "materials/%s.vtf", emojiFile[emojiCount]);
			AddFileToDownloadsTable(vmtpath);
			AddFileToDownloadsTable(vtfpath);
			PrecacheModel(vmtpath, true);
			
			emojiCount++;
		}
		while (kv.GotoNextKey());

		emojiCount--;
	}


	kv.Rewind();
	delete kv;
}

public Action Command_Emoji (int client, int args) {
	if(!IsValidClient(client))	return;

	char name[256];
	GetCmdArg(1, name, sizeof(name));
	StripQuotes(name);

	if(StrEqual(name, "")) {
		ShowEmojiMenu(client, 0);
	} else {
		int id = FindEmojiByName(name);
		if(id > 0 && CanUseEmoji(client, id)) {
			if(CanUseEmoji(client, id)) CreateEmoji(client, id);
			else CPrintToChat(client, "%T", "No Flag", client);
		} 
		else CPrintToChat(client, "%T", "Not Found", client, name);
	}
}

public Action DestroyTimer(Handle timer, any client) {
	DestroyEmoji(client);
}

int FindEmojiByName(const char [] name)
{
	int id = 0;

	for (int i = 1; i <= emojiCount; i++) {
		if(StrEqual(emojiName[i], name)) {
			id = i;
			break;
		}
	}
	
	return id;
}

void ShowEmojiMenu(int client, int start) {
	Menu menu = new Menu(EmojiMenuHandler);

	char title[1024];
	Format(title, sizeof(title), "%T", "Menu Title", client);
	menu.SetTitle(title);
	
	char tmp[32];
	for (int i = 1; i <= emojiCount; i++) {
		IntToString(i, tmp, sizeof(tmp));
		menu.AddItem(tmp, emojiName[i]);
	}

	menu.DisplayAt(client, start, 0);
}

public int EmojiMenuHandler(Menu menu, MenuAction action, int client,int param)
{
	if(action == MenuAction_Select)
	{
		char sid[32];
		menu.GetItem(param, sid, sizeof(sid));
		int id = StringToInt(sid);
		CreateEmoji(client, id);
		ShowEmojiMenu(client, menu.Selection);
	}
}

void CreateEmoji(int client, int id)
{
	if(spirit[client] != INVALID_ENT_REFERENCE) DestroyEmoji(client);

	int ent = CreateEntityByName("env_sprite");
	
	if (IsValidEntity(ent))
	{
		char path[1024];
		Format(path, sizeof(path), "materials/%s.vmt", emojiFile[id]);
		
		DispatchKeyValue(ent, "model", path);
		DispatchSpawn(ent);

		float pos[3];
		GetClientEyePosition(client, pos);
		pos[2] += 20.0;

		TeleportEntity(ent, pos, NULL_VECTOR, NULL_VECTOR);

		SetVariantString("!activator");
		AcceptEntityInput(ent, "SetParent", client, ent, 0);
		
		SetEntPropEnt(ent, Prop_Data, "m_hOwnerEntity", client);

		spirit[client] = EntIndexToEntRef(ent);
		
		SetEdictFlags(ent, 0);
		SetEdictFlags(ent, FL_EDICT_FULLCHECK);
		
		// SDKHook(ent, SDKHook_SetTransmit, OnTrasnmit);

		CreateTimer(duration, DestroyTimer, client);

		CPrintToChat(client, "%T", "Displaying", client, emojiName[id]);
	}
}

// public Action OnTrasnmit(int entity, int client)
// {
// 	int owner = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
// 	if (owner == client || GetListenOverride(client, owner) == Listen_No || IsClientMuted(client, owner))
// 	{
// 		return Plugin_Handled;
// 	}
// 	return Plugin_Continue;
// }

void DestroyEmoji(int client) {
	if(spirit[client] == INVALID_ENT_REFERENCE)	return;

	int ent = EntRefToEntIndex(spirit[client]);
	spirit[client] = INVALID_ENT_REFERENCE;
	
	if(ent == INVALID_ENT_REFERENCE)	return;

	AcceptEntityInput(ent, "Kill");
}

public void OnClientDisconnect(int client) {
	DestroyEmoji(client);
}

stock bool IsValidClient (int client)
{
	if (client <= 0) return false;
	if (client > MaxClients) return false;
	if (!IsClientConnected(client)) return false;
	return IsClientInGame(client);
}

stock bool CanUseEmoji(int client, int id)
{
	if(StrEqual(emojiFlag[id], "") || StrEqual(emojiFlag[id], " "))	return true;
	else
	{
		if (CheckCommandAccess(client, "emoji", ReadFlagString(emojiFlag[id]), true))	return true;
		else return false;
	}
}
