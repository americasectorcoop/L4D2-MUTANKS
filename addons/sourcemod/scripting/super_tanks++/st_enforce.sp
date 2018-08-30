// Super Tanks++: Enforce Ability
#define REQUIRE_PLUGIN
#include <super_tanks++>
#undef REQUIRE_PLUGIN
#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "[ST++] Enforce Ability",
	author = ST_AUTHOR,
	description = ST_DESCRIPTION,
	version = ST_VERSION,
	url = ST_URL
};

bool g_bEnforce[MAXPLAYERS + 1], g_bLateLoad, g_bPluginEnabled, g_bTankConfig[ST_MAXTYPES + 1];
char g_sEnforceSlot[ST_MAXTYPES + 1][6], g_sEnforceSlot2[ST_MAXTYPES + 1][6];
float g_flEnforceDuration[ST_MAXTYPES + 1], g_flEnforceDuration2[ST_MAXTYPES + 1],
	g_flEnforceRange[ST_MAXTYPES + 1], g_flEnforceRange2[ST_MAXTYPES + 1];
int g_iEnforceAbility[ST_MAXTYPES + 1], g_iEnforceAbility2[ST_MAXTYPES + 1],
	g_iEnforceChance[ST_MAXTYPES + 1], g_iEnforceChance2[ST_MAXTYPES + 1],
	g_iEnforceHit[ST_MAXTYPES + 1], g_iEnforceHit2[ST_MAXTYPES + 1],
	g_iEnforceRangeChance[ST_MAXTYPES + 1], g_iEnforceRangeChance2[ST_MAXTYPES + 1],
	g_iEnforceSlot[MAXPLAYERS + 1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();
	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "[ST++] Enforce Ability only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	LibraryExists("super_tanks++") ? (g_bPluginEnabled = true) : (g_bPluginEnabled = false);
}

public void OnLibraryAdded(const char[] name)
{
	if (strcmp(name, "super_tanks++") == 0)
	{
		g_bPluginEnabled = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (strcmp(name, "super_tanks++") == 0)
	{
		g_bPluginEnabled = false;
	}
}

public void OnMapStart()
{
	vReset();
	if (g_bLateLoad)
	{
		for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
		{
			if (bIsValidClient(iPlayer))
			{
				SDKHook(iPlayer, SDKHook_OnTakeDamage, OnTakeDamage);
			}
		}
		g_bLateLoad = false;
	}
}

public void OnClientPostAdminCheck(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	g_bEnforce[client] = false;
	g_iEnforceSlot[client] = -1;
}

public void OnMapEnd()
{
	vReset();
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (!g_bPluginEnabled || !ST_PluginEnabled())
	{
		return Plugin_Continue;
	}
	if (bIsSurvivor(client) && g_bEnforce[client])
	{
		int iActiveWeapon = GetPlayerWeaponSlot(client, g_iEnforceSlot[client]);
		weapon = iActiveWeapon;
	}
	return Plugin_Continue;
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (g_bPluginEnabled && ST_PluginEnabled() && damage > 0.0)
	{
		if (ST_TankAllowed(attacker) && IsPlayerAlive(attacker) && bIsSurvivor(victim))
		{
			char sClassname[32];
			GetEntityClassname(inflictor, sClassname, sizeof(sClassname));
			if (strcmp(sClassname, "weapon_tank_claw") == 0 || strcmp(sClassname, "tank_rock") == 0)
			{
				int iEnforceChance = !g_bTankConfig[ST_TankType(attacker)] ? g_iEnforceChance[ST_TankType(attacker)] : g_iEnforceChance2[ST_TankType(attacker)];
				int iEnforceHit = !g_bTankConfig[ST_TankType(attacker)] ? g_iEnforceHit[ST_TankType(attacker)] : g_iEnforceHit2[ST_TankType(attacker)];
				vEnforceHit(victim, attacker, iEnforceChance, iEnforceHit);
			}
		}
	}
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
			main ? (g_iEnforceAbility[iIndex] = kvSuperTanks.GetNum("Enforce Ability/Ability Enabled", 0)) : (g_iEnforceAbility2[iIndex] = kvSuperTanks.GetNum("Enforce Ability/Ability Enabled", g_iEnforceAbility[iIndex]));
			main ? (g_iEnforceAbility[iIndex] = iSetCellLimit(g_iEnforceAbility[iIndex], 0, 1)) : (g_iEnforceAbility2[iIndex] = iSetCellLimit(g_iEnforceAbility2[iIndex], 0, 1));
			main ? (g_iEnforceChance[iIndex] = kvSuperTanks.GetNum("Enforce Ability/Enforce Chance", 4)) : (g_iEnforceChance2[iIndex] = kvSuperTanks.GetNum("Enforce Ability/Enforce Chance", g_iEnforceChance[iIndex]));
			main ? (g_iEnforceChance[iIndex] = iSetCellLimit(g_iEnforceChance[iIndex], 1, 9999999999)) : (g_iEnforceChance2[iIndex] = iSetCellLimit(g_iEnforceChance2[iIndex], 1, 9999999999));
			main ? (g_flEnforceDuration[iIndex] = kvSuperTanks.GetFloat("Enforce Ability/Enforce Duration", 5.0)) : (g_flEnforceDuration2[iIndex] = kvSuperTanks.GetFloat("Enforce Ability/Enforce Duration", g_flEnforceDuration[iIndex]));
			main ? (g_flEnforceDuration[iIndex] = flSetFloatLimit(g_flEnforceDuration[iIndex], 0.1, 9999999999.0)) : (g_flEnforceDuration2[iIndex] = flSetFloatLimit(g_flEnforceDuration2[iIndex], 0.1, 9999999999.0));
			main ? (g_iEnforceHit[iIndex] = kvSuperTanks.GetNum("Enforce Ability/Enforce Hit", 0)) : (g_iEnforceHit2[iIndex] = kvSuperTanks.GetNum("Enforce Ability/Enforce Hit", g_iEnforceHit[iIndex]));
			main ? (g_iEnforceHit[iIndex] = iSetCellLimit(g_iEnforceHit[iIndex], 0, 1)) : (g_iEnforceHit2[iIndex] = iSetCellLimit(g_iEnforceHit2[iIndex], 0, 1));
			main ? (g_flEnforceRange[iIndex] = kvSuperTanks.GetFloat("Enforce Ability/Enforce Range", 150.0)) : (g_flEnforceRange2[iIndex] = kvSuperTanks.GetFloat("Enforce Ability/Enforce Range", g_flEnforceRange[iIndex]));
			main ? (g_flEnforceRange[iIndex] = flSetFloatLimit(g_flEnforceRange[iIndex], 1.0, 9999999999.0)) : (g_flEnforceRange2[iIndex] = flSetFloatLimit(g_flEnforceRange2[iIndex], 1.0, 9999999999.0));
			main ? (g_iEnforceRangeChance[iIndex] = kvSuperTanks.GetNum("Enforce Ability/Enforce Range Chance", 16)) : (g_iEnforceRangeChance2[iIndex] = kvSuperTanks.GetNum("Enforce Ability/Enforce Range Chance", g_iEnforceRangeChance[iIndex]));
			main ? (g_iEnforceRangeChance[iIndex] = iSetCellLimit(g_iEnforceRangeChance[iIndex], 1, 9999999999)) : (g_iEnforceRangeChance2[iIndex] = iSetCellLimit(g_iEnforceRangeChance2[iIndex], 1, 9999999999));
			main ? (kvSuperTanks.GetString("Enforce Ability/Enforce Weapon Slots", g_sEnforceSlot[iIndex], sizeof(g_sEnforceSlot[]), "12345")) : (kvSuperTanks.GetString("Enforce Ability/Enforce Weapon Slots", g_sEnforceSlot2[iIndex], sizeof(g_sEnforceSlot2[]), g_sEnforceSlot[iIndex]));
			kvSuperTanks.Rewind();
		}
	}
	delete kvSuperTanks;
}

public void ST_Event(Event event, const char[] name)
{
	if (strcmp(name, "player_death") == 0)
	{
		int iTankId = event.GetInt("userid");
		int iTank = GetClientOfUserId(iTankId);
		int iEnforceAbility = !g_bTankConfig[ST_TankType(iTank)] ? g_iEnforceAbility[ST_TankType(iTank)] : g_iEnforceAbility2[ST_TankType(iTank)];
		if (ST_TankAllowed(iTank) && iEnforceAbility == 1)
		{
			vRemoveEnforce();
		}
	}
}

public void ST_Ability(int client)
{
	if (g_bPluginEnabled && ST_TankAllowed(client) && IsPlayerAlive(client))
	{
		int iEnforceAbility = !g_bTankConfig[ST_TankType(client)] ? g_iEnforceAbility[ST_TankType(client)] : g_iEnforceAbility2[ST_TankType(client)];
		int iEnforceRangeChance = !g_bTankConfig[ST_TankType(client)] ? g_iEnforceChance[ST_TankType(client)] : g_iEnforceChance2[ST_TankType(client)];
		float flEnforceRange = !g_bTankConfig[ST_TankType(client)] ? g_flEnforceRange[ST_TankType(client)] : g_flEnforceRange2[ST_TankType(client)];
		float flTankPos[3];
		GetClientAbsOrigin(client, flTankPos);
		for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
		{
			if (bIsSurvivor(iSurvivor))
			{
				float flSurvivorPos[3];
				GetClientAbsOrigin(iSurvivor, flSurvivorPos);
				float flDistance = GetVectorDistance(flTankPos, flSurvivorPos);
				if (flDistance <= flEnforceRange)
				{
					vEnforceHit(iSurvivor, client, iEnforceRangeChance, iEnforceAbility);
				}
			}
		}
	}
}

public void ST_BossStage(int client)
{
	int iEnforceAbility = !g_bTankConfig[ST_TankType(client)] ? g_iEnforceAbility[ST_TankType(client)] : g_iEnforceAbility2[ST_TankType(client)];
	if (g_bPluginEnabled && ST_TankAllowed(client) && iEnforceAbility == 1)
	{
		vRemoveEnforce();
	}
}

void vEnforceHit(int client, int owner, int chance, int enabled)
{
	if (g_bPluginEnabled && enabled == 1 && GetRandomInt(1, chance) == 1 && bIsSurvivor(client) && !g_bEnforce[client])
	{
		g_bEnforce[client] = true;
		char sNumbers = !g_bTankConfig[ST_TankType(owner)] ? g_sEnforceSlot[ST_TankType(owner)][GetRandomInt(0, strlen(g_sEnforceSlot[ST_TankType(owner)]) - 1)] : g_sEnforceSlot2[ST_TankType(owner)][GetRandomInt(0, strlen(g_sEnforceSlot2[ST_TankType(owner)]) - 1)];
		switch (sNumbers)
		{
			case '1': g_iEnforceSlot[client] = 0;
			case '2': g_iEnforceSlot[client] = 1;
			case '3': g_iEnforceSlot[client] = 2;
			case '4': g_iEnforceSlot[client] = 3;
			case '5': g_iEnforceSlot[client] = 4;
		}
		float flEnforceDuration = !g_bTankConfig[ST_TankType(owner)] ? g_flEnforceDuration[ST_TankType(owner)] : g_flEnforceDuration2[ST_TankType(owner)];
		DataPack dpDataPack = new DataPack();
		CreateDataTimer(flEnforceDuration, tTimerStopEnforce, dpDataPack, TIMER_FLAG_NO_MAPCHANGE);
		dpDataPack.WriteCell(GetClientUserId(client));
		dpDataPack.WriteCell(GetClientUserId(owner));
	}
}

void vRemoveEnforce()
{
	for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
	{
		if (bIsSurvivor(iSurvivor) && g_bEnforce[iSurvivor])
		{
			g_bEnforce[iSurvivor] = false;
		}
	}
}

void vReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer))
		{
			g_bEnforce[iPlayer] = false;
			g_iEnforceSlot[iPlayer] = -1;
		}
	}
}

public Action tTimerStopEnforce(Handle timer, DataPack pack)
{
	pack.Reset();
	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!g_bPluginEnabled || !bIsSurvivor(iSurvivor))
	{
		g_bEnforce[iSurvivor] = false;
		return Plugin_Stop;
	}
	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!ST_TankAllowed(iTank) || !IsPlayerAlive(iTank))
	{
		g_bEnforce[iSurvivor] = false;
		return Plugin_Stop;
	}
	int iEnforceAbility = !g_bTankConfig[ST_TankType(iTank)] ? g_iEnforceAbility[ST_TankType(iTank)] : g_iEnforceAbility2[ST_TankType(iTank)];
	if (iEnforceAbility == 0)
	{
		g_bEnforce[iSurvivor] = false;
		return Plugin_Stop;
	}
	g_bEnforce[iSurvivor] = false;
	return Plugin_Continue;
}