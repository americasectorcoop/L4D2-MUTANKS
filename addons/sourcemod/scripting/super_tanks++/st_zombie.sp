/**
 * Super Tanks++: a L4D/L4D2 SourceMod Plugin
 * Copyright (C) 2018  Alfred "Crasher_3637/Psyk0tik" Llagas
 *
 * This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
 **/

// Super Tanks++: Zombie Ability
#include <sourcemod>
#include <sdkhooks>

#undef REQUIRE_PLUGIN
#include <st_clone>
#define REQUIRE_PLUGIN

#include <super_tanks++>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "[ST++] Zombie Ability",
	author = ST_AUTHOR,
	description = "The Super Tank creates zombie mobs.",
	version = ST_VERSION,
	url = ST_URL
};

bool g_bCloneInstalled, g_bLateLoad, g_bTankConfig[ST_MAXTYPES + 1], g_bZombie[MAXPLAYERS + 1];

char g_sZombieEffect[ST_MAXTYPES + 1][4], g_sZombieEffect2[ST_MAXTYPES + 1][4], g_sZombieMessage[ST_MAXTYPES + 1][4], g_sZombieMessage2[ST_MAXTYPES + 1][4];

float g_flZombieChance[ST_MAXTYPES + 1], g_flZombieChance2[ST_MAXTYPES + 1], g_flZombieInterval[ST_MAXTYPES + 1], g_flZombieInterval2[ST_MAXTYPES + 1], g_flZombieRange[ST_MAXTYPES + 1], g_flZombieRange2[ST_MAXTYPES + 1], g_flZombieRangeChance[ST_MAXTYPES + 1], g_flZombieRangeChance2[ST_MAXTYPES + 1];

int g_iZombieAbility[ST_MAXTYPES + 1], g_iZombieAbility2[ST_MAXTYPES + 1], g_iZombieAmount[ST_MAXTYPES + 1], g_iZombieAmount2[ST_MAXTYPES + 1], g_iZombieHit[ST_MAXTYPES + 1], g_iZombieHit2[ST_MAXTYPES + 1], g_iZombieHitMode[ST_MAXTYPES + 1], g_iZombieHitMode2[ST_MAXTYPES + 1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (!bIsValidGame(false) && !bIsValidGame())
	{
		strcopy(error, err_max, "\"[ST++] Zombie Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	g_bLateLoad = late;

	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	g_bCloneInstalled = LibraryExists("st_clone");
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "st_clone", false))
	{
		g_bCloneInstalled = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "st_clone", false))
	{
		g_bCloneInstalled = false;
	}
}

public void OnPluginStart()
{
	LoadTranslations("super_tanks++.phrases");

	if (g_bLateLoad)
	{
		for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
		{
			if (bIsValidClient(iPlayer, "24"))
			{
				OnClientPutInServer(iPlayer);
			}
		}

		g_bLateLoad = false;
	}
}

public void OnMapStart()
{
	vReset();
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);

	g_bZombie[client] = false;
}

public void OnMapEnd()
{
	vReset();
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (ST_PluginEnabled() && damage > 0.0)
	{
		char sClassname[32];
		GetEntityClassname(inflictor, sClassname, sizeof(sClassname));

		if ((iZombieHitMode(attacker) == 0 || iZombieHitMode(attacker) == 1) && ST_TankAllowed(attacker) && ST_CloneAllowed(attacker, g_bCloneInstalled) && bIsSurvivor(victim))
		{
			if (StrEqual(sClassname, "weapon_tank_claw") || StrEqual(sClassname, "tank_rock"))
			{
				vZombieHit(victim, attacker, flZombieChance(attacker), iZombieHit(attacker), "1", "1");
			}
		}
		else if ((iZombieHitMode(victim) == 0 || iZombieHitMode(victim) == 2) && ST_TankAllowed(victim) && ST_CloneAllowed(victim, g_bCloneInstalled) && bIsSurvivor(attacker))
		{
			if (StrEqual(sClassname, "weapon_melee"))
			{
				vZombieHit(attacker, victim, flZombieChance(victim), iZombieHit(victim), "1", "2");
			}
		}
	}
}

public void ST_Configs(const char[] savepath, bool main)
{
	KeyValues kvSuperTanks = new KeyValues("Super Tanks++");
	kvSuperTanks.ImportFromFile(savepath);
	for (int iIndex = ST_MinType(); iIndex <= ST_MaxType(); iIndex++)
	{
		char sTankName[33];
		Format(sTankName, sizeof(sTankName), "Tank #%d", iIndex);
		if (kvSuperTanks.JumpToKey(sTankName))
		{
			if (main)
			{
				g_bTankConfig[iIndex] = false;

				g_iZombieAbility[iIndex] = kvSuperTanks.GetNum("Zombie Ability/Ability Enabled", 0);
				g_iZombieAbility[iIndex] = iClamp(g_iZombieAbility[iIndex], 0, 3);
				kvSuperTanks.GetString("Zombie Ability/Ability Effect", g_sZombieEffect[iIndex], sizeof(g_sZombieEffect[]), "0");
				kvSuperTanks.GetString("Zombie Ability/Ability Message", g_sZombieMessage[iIndex], sizeof(g_sZombieMessage[]), "0");
				g_iZombieAmount[iIndex] = kvSuperTanks.GetNum("Zombie Ability/Zombie Amount", 10);
				g_iZombieAmount[iIndex] = iClamp(g_iZombieAmount[iIndex], 1, 100);
				g_flZombieChance[iIndex] = kvSuperTanks.GetFloat("Zombie Ability/Zombie Chance", 33.3);
				g_flZombieChance[iIndex] = flClamp(g_flZombieChance[iIndex], 0.0, 100.0);
				g_iZombieHit[iIndex] = kvSuperTanks.GetNum("Zombie Ability/Zombie Hit", 0);
				g_iZombieHit[iIndex] = iClamp(g_iZombieHit[iIndex], 0, 1);
				g_iZombieHitMode[iIndex] = kvSuperTanks.GetNum("Zombie Ability/Zombie Hit Mode", 0);
				g_iZombieHitMode[iIndex] = iClamp(g_iZombieHitMode[iIndex], 0, 2);
				g_flZombieInterval[iIndex] = kvSuperTanks.GetFloat("Zombie Ability/Zombie Interval", 5.0);
				g_flZombieInterval[iIndex] = flClamp(g_flZombieInterval[iIndex], 0.1, 9999999999.0);
				g_flZombieRange[iIndex] = kvSuperTanks.GetFloat("Zombie Ability/Zombie Range", 150.0);
				g_flZombieRange[iIndex] = flClamp(g_flZombieRange[iIndex], 1.0, 9999999999.0);
				g_flZombieRangeChance[iIndex] = kvSuperTanks.GetFloat("Zombie Ability/Zombie Range Chance", 15.0);
				g_flZombieRangeChance[iIndex] = flClamp(g_flZombieRangeChance[iIndex], 0.0, 100.0);
			}
			else
			{
				g_bTankConfig[iIndex] = true;

				g_iZombieAbility2[iIndex] = kvSuperTanks.GetNum("Zombie Ability/Ability Enabled", g_iZombieAbility[iIndex]);
				g_iZombieAbility2[iIndex] = iClamp(g_iZombieAbility2[iIndex], 0, 3);
				kvSuperTanks.GetString("Zombie Ability/Ability Effect", g_sZombieEffect2[iIndex], sizeof(g_sZombieEffect2[]), g_sZombieEffect[iIndex]);
				kvSuperTanks.GetString("Zombie Ability/Ability Message", g_sZombieMessage2[iIndex], sizeof(g_sZombieMessage2[]), g_sZombieMessage[iIndex]);
				g_iZombieAmount2[iIndex] = kvSuperTanks.GetNum("Zombie Ability/Zombie Amount", g_iZombieAmount[iIndex]);
				g_iZombieAmount2[iIndex] = iClamp(g_iZombieAmount2[iIndex], 1, 100);
				g_flZombieChance2[iIndex] = kvSuperTanks.GetFloat("Zombie Ability/Zombie Chance", g_flZombieChance[iIndex]);
				g_flZombieChance2[iIndex] = flClamp(g_flZombieChance2[iIndex], 0.0, 100.0);
				g_iZombieHit2[iIndex] = kvSuperTanks.GetNum("Zombie Ability/Zombie Hit", g_iZombieHit[iIndex]);
				g_iZombieHit2[iIndex] = iClamp(g_iZombieHit2[iIndex], 0, 1);
				g_iZombieHitMode2[iIndex] = kvSuperTanks.GetNum("Zombie Ability/Zombie Hit Mode", g_iZombieHitMode[iIndex]);
				g_iZombieHitMode2[iIndex] = iClamp(g_iZombieHitMode2[iIndex], 0, 2);
				g_flZombieInterval2[iIndex] = kvSuperTanks.GetFloat("Zombie Ability/Zombie Interval", g_flZombieInterval[iIndex]);
				g_flZombieInterval2[iIndex] = flClamp(g_flZombieInterval2[iIndex], 0.1, 9999999999.0);
				g_flZombieRange2[iIndex] = kvSuperTanks.GetFloat("Zombie Ability/Zombie Range", g_flZombieRange[iIndex]);
				g_flZombieRange2[iIndex] = flClamp(g_flZombieRange2[iIndex], 1.0, 9999999999.0);
				g_flZombieRangeChance2[iIndex] = kvSuperTanks.GetFloat("Zombie Ability/Zombie Range Chance", g_flZombieRangeChance[iIndex]);
				g_flZombieRangeChance2[iIndex] = flClamp(g_flZombieRangeChance2[iIndex], 0.0, 100.0);
			}

			kvSuperTanks.Rewind();
		}
	}

	delete kvSuperTanks;
}

public void ST_EventHandler(Event event, const char[] name)
{
	if (StrEqual(name, "player_death"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (iZombieAbility(iTank) == 1 && GetRandomFloat(0.1, 100.0) <= flZombieChance(iTank) && ST_TankAllowed(iTank, "024") && ST_CloneAllowed(iTank, g_bCloneInstalled))
		{
			vZombie(iTank);
		}
	}
}

public void ST_Ability(int tank)
{
	if (ST_TankAllowed(tank) && ST_CloneAllowed(tank, g_bCloneInstalled) && !g_bZombie[tank])
	{
		float flZombieRange = !g_bTankConfig[ST_TankType(tank)] ? g_flZombieRange[ST_TankType(tank)] : g_flZombieRange2[ST_TankType(tank)],
			flZombieRangeChance = !g_bTankConfig[ST_TankType(tank)] ? g_flZombieRangeChance[ST_TankType(tank)] : g_flZombieRangeChance2[ST_TankType(tank)],
			flTankPos[3];

		GetClientAbsOrigin(tank, flTankPos);

		for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
		{
			if (bIsSurvivor(iSurvivor, "234"))
			{
				float flSurvivorPos[3];
				GetClientAbsOrigin(iSurvivor, flSurvivorPos);

				float flDistance = GetVectorDistance(flTankPos, flSurvivorPos);
				if (flDistance <= flZombieRange)
				{
					vZombieHit(iSurvivor, tank, flZombieRangeChance, iZombieAbility(tank), "2", "3");
				}
			}
		}

		if ((iZombieAbility(tank) == 2 || iZombieAbility(tank) == 3) && !g_bZombie[tank])
		{
			g_bZombie[tank] = true;
			float flZombieInterval = !g_bTankConfig[ST_TankType(tank)] ? g_flZombieInterval[ST_TankType(tank)] : g_flZombieInterval2[ST_TankType(tank)];
			CreateTimer(flZombieInterval, tTimerZombie, GetClientUserId(tank), TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
		}
	}
}

public void ST_ChangeType(int tank)
{
	g_bZombie[tank] = false;
}

static void vReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, "24"))
		{
			g_bZombie[iPlayer] = false;
		}
	}
}

static void vZombie(int tank)
{
	int iZombieAmount = !g_bTankConfig[ST_TankType(tank)] ? g_iZombieAmount[ST_TankType(tank)] : g_iZombieAmount2[ST_TankType(tank)];
	for (int iZombie = 1; iZombie <= iZombieAmount; iZombie++)
	{
		vCheatCommand(tank, bIsValidGame() ? "z_spawn_old" : "z_spawn", "zombie area");
	}
}

static void vZombieHit(int survivor, int tank, float chance, int enabled, const char[] message, const char[] mode)
{
	if ((enabled == 1 || enabled == 3) && GetRandomFloat(0.1, 100.0) <= chance && bIsSurvivor(survivor))
	{
		vZombie(survivor);

		char sZombieEffect[4];
		sZombieEffect = !g_bTankConfig[ST_TankType(tank)] ? g_sZombieEffect[ST_TankType(tank)] : g_sZombieEffect2[ST_TankType(tank)];
		vEffect(survivor, tank, sZombieEffect, mode);

		char sZombieMessage[4];
		sZombieMessage = !g_bTankConfig[ST_TankType(tank)] ? g_sZombieMessage[ST_TankType(tank)] : g_sZombieMessage2[ST_TankType(tank)];
		if (StrContains(sZombieMessage, message) != -1)
		{
			char sTankName[33];
			ST_TankName(tank, sTankName);
			ST_PrintToChatAll("%s %t", ST_TAG2, "Zombie", sTankName);
		}
	}
}

static float flZombieChance(int tank)
{
	return !g_bTankConfig[ST_TankType(tank)] ? g_flZombieChance[ST_TankType(tank)] : g_flZombieChance2[ST_TankType(tank)];
}

static int iZombieAbility(int tank)
{
	return !g_bTankConfig[ST_TankType(tank)] ? g_iZombieAbility[ST_TankType(tank)] : g_iZombieAbility2[ST_TankType(tank)];
}

static int iZombieHit(int tank)
{
	return !g_bTankConfig[ST_TankType(tank)] ? g_iZombieHit[ST_TankType(tank)] : g_iZombieHit2[ST_TankType(tank)];
}

static int iZombieHitMode(int tank)
{
	return !g_bTankConfig[ST_TankType(tank)] ? g_iZombieHitMode[ST_TankType(tank)] : g_iZombieHitMode2[ST_TankType(tank)];
}

public Action tTimerZombie(Handle timer, int userid)
{
	int iTank = GetClientOfUserId(userid);
	if (!ST_TankAllowed(iTank) || !ST_TypeEnabled(ST_TankType(iTank)) || !ST_CloneAllowed(iTank, g_bCloneInstalled) || iZombieAbility(iTank) == 0 || !g_bZombie[iTank])
	{
		g_bZombie[iTank] = false;

		return Plugin_Stop;
	}

	vZombie(iTank);

	char sZombieMessage[4];
	sZombieMessage = !g_bTankConfig[ST_TankType(iTank)] ? g_sZombieMessage[ST_TankType(iTank)] : g_sZombieMessage2[ST_TankType(iTank)];
	if (StrContains(sZombieMessage, "3") != -1)
	{
		char sTankName[33];
		ST_TankName(iTank, sTankName);
		ST_PrintToChatAll("%s %t", ST_TAG2, "Zombie", sTankName);
	}

	return Plugin_Continue;
}