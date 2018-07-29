// Super Tanks++: Hypno Ability
#pragma semicolon 1
#pragma newdecls required
#include <super_tanks++>

public Plugin myinfo =
{
	name = "[ST++] Hypno Ability",
	author = ST_AUTHOR,
	description = ST_DESCRIPTION,
	version = ST_VERSION,
	url = ST_URL
};

bool g_bHypno[MAXPLAYERS + 1];
bool g_bLateLoad;
bool g_bTankConfig[ST_MAXTYPES + 1];
float g_flHypnoDuration[ST_MAXTYPES + 1];
float g_flHypnoDuration2[ST_MAXTYPES + 1];
float g_flHypnoRange[ST_MAXTYPES + 1];
float g_flHypnoRange2[ST_MAXTYPES + 1];
int g_iHypnoAbility[ST_MAXTYPES + 1];
int g_iHypnoAbility2[ST_MAXTYPES + 1];
int g_iHypnoChance[ST_MAXTYPES + 1];
int g_iHypnoChance2[ST_MAXTYPES + 1];
int g_iHypnoHit[ST_MAXTYPES + 1];
int g_iHypnoHit2[ST_MAXTYPES + 1];
int g_iHypnoMode[ST_MAXTYPES + 1];
int g_iHypnoMode2[ST_MAXTYPES + 1];
int g_iHypnoRangeChance[ST_MAXTYPES + 1];
int g_iHypnoRangeChance2[ST_MAXTYPES + 1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();
	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "[ST++] Hypno Ability only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	if (!LibraryExists("super_tanks++"))
	{
		SetFailState("No Super Tanks++ library found.");
	}
}

public void OnMapStart()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer))
		{
			g_bHypno[iPlayer] = false;
		}
	}
	if (g_bLateLoad)
	{
		vLateLoad(true);
		g_bLateLoad = false;
	}
}

public void OnClientPostAdminCheck(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	g_bHypno[client] = false;
}

public void OnClientDisconnect(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	g_bHypno[client] = false;
}

public void OnMapEnd()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer))
		{
			g_bHypno[iPlayer] = false;
		}
	}
}

void vLateLoad(bool late)
{
	if (late)
	{
		for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
		{
			if (bIsValidClient(iPlayer))
			{
				SDKHook(iPlayer, SDKHook_OnTakeDamage, OnTakeDamage);
			}
		}
	}
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (ST_PluginEnabled() && damage > 0.0)
	{
		if (ST_TankAllowed(attacker) && IsPlayerAlive(attacker) && bIsSurvivor(victim))
		{
			char sClassname[32];
			GetEntityClassname(inflictor, sClassname, sizeof(sClassname));
			if (strcmp(sClassname, "weapon_tank_claw") == 0 || strcmp(sClassname, "tank_rock") == 0)
			{
				int iHypnoChance = !g_bTankConfig[ST_TankType(attacker)] ? g_iHypnoChance[ST_TankType(attacker)] : g_iHypnoChance2[ST_TankType(attacker)];
				int iHypnoHit = !g_bTankConfig[ST_TankType(attacker)] ? g_iHypnoHit[ST_TankType(attacker)] : g_iHypnoHit2[ST_TankType(attacker)];
				vHypnoHit(victim, attacker, iHypnoChance, iHypnoHit);
			}
		}
		else if (ST_TankAllowed(victim) && IsPlayerAlive(victim) && bIsSurvivor(attacker) && g_bHypno[attacker])
		{
			if (damagetype & DMG_BURN)
			{
				damage = 0.0;
				return Plugin_Handled;
			}
			else
			{
				int iHypnoMode = !g_bTankConfig[ST_TankType(victim)] ? g_iHypnoMode[ST_TankType(victim)] : g_iHypnoMode2[ST_TankType(victim)];
				int iHealth = GetClientHealth(attacker);
				int iTarget = iGetRandomSurvivor(attacker);
				if (damagetype & DMG_BULLET || damagetype & DMG_BLAST || damagetype & DMG_BLAST_SURFACE || damagetype & DMG_AIRBOAT || damagetype & DMG_PLASMA)
				{
					damage = damage / 10;
				}
				else if (damagetype & DMG_SLASH || damagetype & DMG_CLUB)
				{
					damage = damage / 1000;
				}
				(iHealth > damage) ? ((iHypnoMode == 1 && iTarget > 0) ? SetEntityHealth(iTarget, iHealth - RoundFloat(damage)) : SetEntityHealth(attacker, iHealth - RoundFloat(damage))) : ((iHypnoMode == 1 && iTarget > 0) ? SetEntProp(iTarget, Prop_Send, "m_isIncapacitated", 1) : SetEntProp(attacker, Prop_Send, "m_isIncapacitated", 1));
				damage = 0.0;
				return Plugin_Changed;
			}
		}
	}
	return Plugin_Continue;
}

public void ST_Configs(char[] savepath, int limit, bool main)
{
	KeyValues kvSuperTanks = new KeyValues("Super Tanks++");
	kvSuperTanks.ImportFromFile(savepath);
	for (int iIndex = 1; iIndex <= limit; iIndex++)
	{
		char sName[MAX_NAME_LENGTH + 1];
		Format(sName, sizeof(sName), "Tank %d", iIndex);
		if (kvSuperTanks.JumpToKey(sName))
		{
			main ? (g_bTankConfig[iIndex] = false) : (g_bTankConfig[iIndex] = true);
			main ? (g_iHypnoAbility[iIndex] = kvSuperTanks.GetNum("Hypno Ability/Ability Enabled", 0)) : (g_iHypnoAbility2[iIndex] = kvSuperTanks.GetNum("Hypno Ability/Ability Enabled", g_iHypnoAbility[iIndex]));
			main ? (g_iHypnoAbility[iIndex] = iSetCellLimit(g_iHypnoAbility[iIndex], 0, 1)) : (g_iHypnoAbility2[iIndex] = iSetCellLimit(g_iHypnoAbility2[iIndex], 0, 1));
			main ? (g_iHypnoChance[iIndex] = kvSuperTanks.GetNum("Hypno Ability/Hypno Chance", 4)) : (g_iHypnoChance2[iIndex] = kvSuperTanks.GetNum("Hypno Ability/Hypno Chance", g_iHypnoChance[iIndex]));
			main ? (g_iHypnoChance[iIndex] = iSetCellLimit(g_iHypnoChance[iIndex], 1, 9999999999)) : (g_iHypnoChance2[iIndex] = iSetCellLimit(g_iHypnoChance2[iIndex], 1, 9999999999));
			main ? (g_flHypnoDuration[iIndex] = kvSuperTanks.GetFloat("Hypno Ability/Hypno Duration", 5.0)) : (g_flHypnoDuration2[iIndex] = kvSuperTanks.GetFloat("Hypno Ability/Hypno Duration", g_flHypnoDuration[iIndex]));
			main ? (g_flHypnoDuration[iIndex] = flSetFloatLimit(g_flHypnoDuration[iIndex], 0.1, 9999999999.0)) : (g_flHypnoDuration2[iIndex] = flSetFloatLimit(g_flHypnoDuration2[iIndex], 0.1, 9999999999.0));
			main ? (g_iHypnoHit[iIndex] = kvSuperTanks.GetNum("Hypno Ability/Hypno Hit", 0)) : (g_iHypnoHit2[iIndex] = kvSuperTanks.GetNum("Hypno Ability/Hypno Hit", g_iHypnoHit[iIndex]));
			main ? (g_iHypnoHit[iIndex] = iSetCellLimit(g_iHypnoHit[iIndex], 0, 1)) : (g_iHypnoHit2[iIndex] = iSetCellLimit(g_iHypnoHit2[iIndex], 0, 1));
			main ? (g_iHypnoMode[iIndex] = kvSuperTanks.GetNum("Hypno Ability/Hypno Mode", 0)) : (g_iHypnoMode2[iIndex] = kvSuperTanks.GetNum("Hypno Ability/Hypno Mode", g_iHypnoMode[iIndex]));
			main ? (g_iHypnoMode[iIndex] = iSetCellLimit(g_iHypnoMode[iIndex], 0, 1)) : (g_iHypnoMode2[iIndex] = iSetCellLimit(g_iHypnoMode2[iIndex], 0, 1));
			main ? (g_flHypnoRange[iIndex] = kvSuperTanks.GetFloat("Hypno Ability/Hypno Range", 150.0)) : (g_flHypnoRange2[iIndex] = kvSuperTanks.GetFloat("Hypno Ability/Hypno Range", g_flHypnoRange[iIndex]));
			main ? (g_flHypnoRange[iIndex] = flSetFloatLimit(g_flHypnoRange[iIndex], 1.0, 9999999999.0)) : (g_flHypnoRange2[iIndex] = flSetFloatLimit(g_flHypnoRange2[iIndex], 1.0, 9999999999.0));
			main ? (g_iHypnoRangeChance[iIndex] = kvSuperTanks.GetNum("Hypno Ability/Hypno Range Chance", 16)) : (g_iHypnoRangeChance2[iIndex] = kvSuperTanks.GetNum("Hypno Ability/Hypno Range Chance", g_iHypnoRangeChance[iIndex]));
			main ? (g_iHypnoRangeChance[iIndex] = iSetCellLimit(g_iHypnoRangeChance[iIndex], 1, 9999999999)) : (g_iHypnoRangeChance2[iIndex] = iSetCellLimit(g_iHypnoRangeChance2[iIndex], 1, 9999999999));
			kvSuperTanks.Rewind();
		}
	}
	delete kvSuperTanks;
}

public void ST_Death(int client)
{
	int iHypnoAbility = !g_bTankConfig[ST_TankType(client)] ? g_iHypnoAbility[ST_TankType(client)] : g_iHypnoAbility2[ST_TankType(client)];
	if (ST_TankAllowed(client) && iHypnoAbility == 1)
	{
		for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
		{
			if (bIsSurvivor(iSurvivor) && g_bHypno[iSurvivor])
			{
				g_bHypno[iSurvivor] = false;
			}
		}
	}
}

public void ST_Ability(int client)
{
	if (ST_TankAllowed(client) && IsPlayerAlive(client))
	{
		int iHypnoAbility = !g_bTankConfig[ST_TankType(client)] ? g_iHypnoAbility[ST_TankType(client)] : g_iHypnoAbility2[ST_TankType(client)];
		int iHypnoRangeChance = !g_bTankConfig[ST_TankType(client)] ? g_iHypnoChance[ST_TankType(client)] : g_iHypnoChance2[ST_TankType(client)];
		float flHypnoRange = !g_bTankConfig[ST_TankType(client)] ? g_flHypnoRange[ST_TankType(client)] : g_flHypnoRange2[ST_TankType(client)];
		float flTankPos[3];
		GetClientAbsOrigin(client, flTankPos);
		for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
		{
			if (bIsSurvivor(iSurvivor))
			{
				float flSurvivorPos[3];
				GetClientAbsOrigin(iSurvivor, flSurvivorPos);
				float flDistance = GetVectorDistance(flTankPos, flSurvivorPos);
				if (flDistance <= flHypnoRange)
				{
					vHypnoHit(iSurvivor, client, iHypnoRangeChance, iHypnoAbility);
				}
			}
		}
	}
}

void vHypnoHit(int client, int owner, int chance, int enabled)
{
	if (enabled == 1 && GetRandomInt(1, chance) == 1 && bIsSurvivor(client) && !g_bHypno[client])
	{
		g_bHypno[client] = true;
		float flHypnoDuration = !g_bTankConfig[ST_TankType(owner)] ? g_flHypnoDuration[ST_TankType(owner)] : g_flHypnoDuration2[ST_TankType(owner)];
		DataPack dpDataPack;
		CreateDataTimer(flHypnoDuration, tTimerStopHypno, dpDataPack, TIMER_FLAG_NO_MAPCHANGE);
		dpDataPack.WriteCell(GetClientUserId(client));
		dpDataPack.WriteCell(GetClientUserId(owner));
	}
}

int iGetRandomSurvivor(int client)
{
	int iSurvivorCount;
	int iSurvivors[MAXPLAYERS + 1];
	for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
	{
		if (bIsSurvivor(iSurvivor) && iSurvivor != client)
		{
			iSurvivors[iSurvivorCount++] = iSurvivor;
		}
	}
	return iSurvivors[GetRandomInt(0, iSurvivorCount - 1)];
}

bool bIsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && !IsClientInKickQueue(client);
}

public Action tTimerStopHypno(Handle timer, DataPack pack)
{
	pack.Reset();
	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	int iTank = GetClientOfUserId(pack.ReadCell());
	int iHypnoAbility = !g_bTankConfig[ST_TankType(iTank)] ? g_iHypnoAbility[ST_TankType(iTank)] : g_iHypnoAbility2[ST_TankType(iTank)];
	if (iHypnoAbility == 0 || !bIsTank(iTank) || !IsPlayerAlive(iTank) || !bIsSurvivor(iSurvivor))
	{
		g_bHypno[iSurvivor] = false;
		return Plugin_Stop;
	}
	if (bIsSurvivor(iSurvivor))
	{
		g_bHypno[iSurvivor] = false;
	}
	return Plugin_Continue;
}