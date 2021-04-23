#include <sourcemod>
#include <smlib>
#include <discord_utilities>
#include <multicolors>

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo = 
{
    name 			= "Give Roles",
    author 			= "Nano",
    description 		= "Automatically give roles on discord when players join, or link their accounts, or claim their roles",
    version 			= "1.2",
    url 				= "https://steamcommunity.com/id/nano2k06/"
};

char g_sPath[PLATFORM_MAX_PATH];

/*-------------------------
-----Purpose: Forwards-----
-------------------------*/

public void OnPluginStart()
{
	HookEvent("player_connect_full", Event_PlayerConnect);
	
	BuildPath(Path_SM, g_sPath, sizeof(g_sPath), "configs/GiveRoles.cfg");
	if(!FileExists(g_sPath))
	{
		SetFailState("Could not find config: \"%s\"", g_sPath);
		return;
	}
}

public void Event_PlayerConnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsValidClient(client))
	{
		return;
	}

	HandleRoles(client);
}

/*-------------------------
------Purpose: Voids-------
--------------------------*/

void HandleRoles(int client)
{
	char	sFlags[30], sTempFlag[32], sRolesGroupID[256], sRoleID[32];

	int iFlagCount;

	KeyValues g_sKeyValues = CreateKeyValues("GiveRoles");
	
	g_sKeyValues.ImportFromFile(g_sPath);
	if (!g_sKeyValues.GotoFirstSubKey())
		return;

	do
	{
		g_sKeyValues.GetSectionName(sRoleID, sizeof(sRoleID));
		g_sKeyValues.GetString("name", sRolesGroupID, sizeof(sRolesGroupID));   
		g_sKeyValues.GetString("flags", sFlags, sizeof(sFlags));

		iFlagCount = strlen(sFlags);
		
		for (int x = 0; x < iFlagCount; x++)
		{
			Format(sTempFlag, 2, sFlags[x]);
			if(StrContains("abcdefghijklmnopqrst", sTempFlag) != -1)
			{
				GetFlagInt(sTempFlag);
				int iFlag = StringToInt(sTempFlag);

				if(IsClientInGame(client) && GetUserAdmin(client).HasFlag(Admin_Root))
				{
					return;
				}
				if(IsValidClient(client))
				{
					if(Client_HasAdminFlags(client, iFlag))
					{
						DU_AddRole(client, sRoleID);
					}
					else
					{
						DU_DeleteRole(client, sRoleID);
					}
				}
			}
		}
	}
	while (g_sKeyValues.GotoNextKey());
	delete g_sKeyValues;
}

/*-------------------------
------Purpose: Stocks------
-------------------------*/

stock void GetFlagInt(char sBuffer[30])
{
	FlagStringToInt(sBuffer, "a", ADMFLAG_RESERVATION);
	FlagStringToInt(sBuffer, "b", ADMFLAG_GENERIC);
	FlagStringToInt(sBuffer, "c", ADMFLAG_KICK);
	FlagStringToInt(sBuffer, "d", ADMFLAG_BAN);
	FlagStringToInt(sBuffer, "e", ADMFLAG_UNBAN);
	FlagStringToInt(sBuffer, "f", ADMFLAG_SLAY);
	FlagStringToInt(sBuffer, "g", ADMFLAG_CHANGEMAP);
	FlagStringToInt(sBuffer, "h", 128);
	FlagStringToInt(sBuffer, "i", ADMFLAG_CONFIG);
	FlagStringToInt(sBuffer, "j", ADMFLAG_CHAT);
	FlagStringToInt(sBuffer, "k", ADMFLAG_VOTE);
	FlagStringToInt(sBuffer, "l", ADMFLAG_PASSWORD);
	FlagStringToInt(sBuffer, "m", ADMFLAG_RCON);
	FlagStringToInt(sBuffer, "n", ADMFLAG_CHEATS);
	FlagStringToInt(sBuffer, "o", ADMFLAG_CUSTOM1);
	FlagStringToInt(sBuffer, "p", ADMFLAG_CUSTOM2);
	FlagStringToInt(sBuffer, "q", ADMFLAG_CUSTOM3);
	FlagStringToInt(sBuffer, "r", ADMFLAG_CUSTOM4);
	FlagStringToInt(sBuffer, "s", ADMFLAG_CUSTOM5);
	FlagStringToInt(sBuffer, "t", ADMFLAG_CUSTOM6);
}

stock void FlagStringToInt(char sStrToReplace[30], char sFlag[10], int iReplaceWith)
{
	char sNewFlagValue[10];
	IntToString(iReplaceWith, sNewFlagValue, sizeof(sNewFlagValue));
	ReplaceString(sStrToReplace, sizeof(sStrToReplace), sFlag, sNewFlagValue, false);
}

stock bool IsValidClient(int client)
{
	if((1 <= client <= MaxClients) 
	&& IsClientInGame(client) 
	&& !IsFakeClient(client)
	&& DU_IsChecked(client)	
	&& DU_IsMember(client)
	&& IsClientConnected(client))
		return true;
	return false;
}