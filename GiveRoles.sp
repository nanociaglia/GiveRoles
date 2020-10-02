#include <sourcemod>
#include <smlib>
#include <discord_utilities>
#include <multicolors>

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo = 
{
    name = "Give Roles",
    author = "Nano",
    description = "Automatically give roles on discord when players join, or link their accounts, or claim their roles",
    version = "1.1",
    url = "https://steamcommunity.com/id/nano2k06/"
};

ConVar 	g_cInterval, 
		g_cMethod,
		g_cCmd;

char	g_sPath[PLATFORM_MAX_PATH];

bool	g_bIsCommandPlayer[MAXPLAYERS+1] = {false, ...},
		g_bIsTimer 		= false,
		g_bIsLink 		= false,
		g_bIsCommand	= false;

/*-------------------------
-----Porpuse: Forwards-----
-------------------------*/

public void OnPluginStart()
{
	g_cInterval	= CreateConVar("sm_gr_interval", 	"30",	"Time in seconds to refresh timer to check players flags (recommended a value greater than 10) (Default = 30)");
	g_cMethod 	= CreateConVar("sm_gr_method", 		"2",	"What method do you want to use? 1 = Everytime an user links his account | 2 = Using a timer (in seconds) that checks player's flags to add/remove discord roles. | 3 = Using a command to claim role | 4 = All methods (Default = 2)", _, true, 1.0, true, 4.0);
	g_cCmd 		= CreateConVar("sm_gr_command", 	"0",	"Individual cvar to restrict commands and use the other 3 methods. This should be enabled if you are using 'sm_gr_method 3 or 4'. 1 = Enabled | 0 = Disabled (Default = 0)");
	
	BuildPath(Path_SM, g_sPath, sizeof(g_sPath), "configs/GiveRoles.cfg");
	if(!FileExists(g_sPath))
	{
		SetFailState("Could not find config: \"%s\"", g_sPath);
		return;
	}
	
	RegConsoleCmd("sm_claimrole", 	Command_ClaimRole);
	RegConsoleCmd("sm_discordrole", Command_ClaimRole);
	RegConsoleCmd("sm_giverole", 	Command_ClaimRole);

	AutoExecConfig(true, "GiveRoles");
}

public void OnMapStart()
{
	CreateTimer(g_cInterval.FloatValue, Timer_CheckRoles, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public void DU_OnLinkedAccount(int client, const char[] userid, const char[] username, const char[] discriminator)
{
	if(g_cMethod.IntValue == 2 || g_cMethod.IntValue == 3)
	{
		g_bIsLink = false;
		return;
	}

	g_bIsLink = true;
	HandleRoles();
}

public Action Command_ClaimRole(int client, int args)
{
	if(!client)
	{
		return Plugin_Handled;
	}

	if(GetUserAdmin(client).HasFlag(Admin_Generic))
	{
		if(g_cCmd.IntValue == 0 || g_cCmd.IntValue >= 2)
		{
			CPrintToChat(client, "{green}[DiscordRoles]{default} This feature is currently {darkred}disabled!");
			CPrintToChat(client, "{green}[DiscordRoles]{default} Set the following cvar to 1: {green}sm_gr_command \"1\"");
			return Plugin_Handled;
		}
	}
	
	if(g_cCmd.IntValue == 0 || g_cCmd.IntValue >= 2)
	{
		return Plugin_Handled;
	}
	
	if(!g_cCmd.BoolValue)
	{
		CPrintToChat(client, "{green}[DiscordRoles]{default} This command is currently {darkred}disabled!");
		return Plugin_Handled;
	}

	g_bIsCommand = true;
	g_bIsCommandPlayer[client] = true;
	HandleRoles();
	return Plugin_Handled;
}

/*-------------------------
------Porpuse: Timers------
-------------------------*/

public Action Timer_CheckRoles(Handle timer)
{
	if(g_cMethod.IntValue == 1 || g_cMethod.IntValue == 3)
	{
		g_bIsTimer = false;
		return;
	}

	g_bIsTimer = true;
	HandleRoles();
}

/*-------------------------
------Porpuse: Voids-------
--------------------------*/

void HandleRoles()
{
	char	sFlags[30], sTempFlag[32], sRolesGroupID[256],
			sRoleID[32], sDisplayText[512];

	int		iFlagCount;

	KeyValues g_sKeyValues = CreateKeyValues("GiveRoles");
	
	g_sKeyValues.ImportFromFile(g_sPath);
	if (!g_sKeyValues.GotoFirstSubKey())
		return;

	do
	{
		g_sKeyValues.GetSectionName(sRoleID, 			sizeof(sRoleID));
		g_sKeyValues.GetString("name", 	sRolesGroupID, 	sizeof(sRolesGroupID));   
		g_sKeyValues.GetString("flags", sFlags,		 	sizeof(sFlags));

		iFlagCount = strlen(sFlags);
		
		for (int x = 0; x < iFlagCount; x++)
		{
			Format(sTempFlag, 2, sFlags[x]);
			if(StrContains("abcdefghijklmnopqrst", sTempFlag) != -1)
			{
				GetFlagInt(sTempFlag);
				int iFlag = StringToInt(sTempFlag);

				for(int i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && GetUserAdmin(i).HasFlag(Admin_Root))
					{
						return;
					}
					if(g_bIsCommand)
					{
						if(g_bIsCommandPlayer[i])
						{
							if(Client_HasAdminFlags(i, iFlag))
							{
								Format(sDisplayText, sizeof(sDisplayText), "<span font color='#00FFFF'>───────────</font></span>Discord Roles <span font color='#00FFFF'>───────────</font></span>\nYou have successfully claimed your Discord role!");
								PrintHintText(i, sDisplayText);
								CPrintToChat(i, "{green}[DiscordRoles]{default} You have successfully claimed your {green}Discord role!");
								g_bIsCommandPlayer[i] = false;
							}
						}
					}
					if(IsValidClient(i))
					{
						if(Client_HasAdminFlags(i, iFlag))
						{
							DU_AddRole(i, sRoleID);
							if(g_bIsLink)
							{
								Format(sDisplayText, sizeof(sDisplayText), "<span font color='#00FFFF'>───────────</font></span>Discord Roles <span font color='#00FFFF'>───────────</font></span>\nYou have now a Discord role on our Discord server!");
								PrintHintText(i, sDisplayText);
							}
						}
						else
						{
							if(g_bIsTimer)
							{
								DU_DeleteRole(i, sRoleID);
							}
						}
					}
				}
			}
		}
	}
	while (g_sKeyValues.GotoNextKey());
	delete g_sKeyValues;
}

/*-------------------------
------Porpuse: Stocks------
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