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
	name = "[ST++] Fragile Ability",
	author = ST_AUTHOR,
	description = "The Super Tank takes more damage.",
	version = ST_VERSION,
	url = ST_URL
};

bool g_bLateLoad;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (!bIsValidGame(false) && !bIsValidGame())
	{
		strcopy(error, err_max, "\"[ST++] Fragile Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	g_bLateLoad = late;

	return APLRes_Success;
}

#define ST_MENU_FRAGILE "Fragile Ability"

bool g_bCloneInstalled, g_bFragile[MAXPLAYERS + 1], g_bFragile2[MAXPLAYERS + 1], g_bTankConfig[ST_MAXTYPES + 1];

float g_flFragileBulletMultiplier[ST_MAXTYPES + 1], g_flFragileBulletMultiplier2[ST_MAXTYPES + 1], g_flFragileChance[ST_MAXTYPES + 1], g_flFragileChance2[ST_MAXTYPES + 1], g_flFragileDuration[ST_MAXTYPES + 1], g_flFragileDuration2[ST_MAXTYPES + 1], g_flFragileExplosiveMultiplier[ST_MAXTYPES + 1], g_flFragileExplosiveMultiplier2[ST_MAXTYPES + 1], g_flFragileFireMultiplier[ST_MAXTYPES + 1], g_flFragileFireMultiplier2[ST_MAXTYPES + 1], g_flFragileMeleeMultiplier[ST_MAXTYPES + 1], g_flFragileMeleeMultiplier2[ST_MAXTYPES + 1], g_flHumanCooldown[ST_MAXTYPES + 1], g_flHumanCooldown2[ST_MAXTYPES + 1];

int g_iFragileAbility[ST_MAXTYPES + 1], g_iFragileAbility2[ST_MAXTYPES + 1], g_iFragileCount[MAXPLAYERS + 1], g_iFragileMessage[ST_MAXTYPES + 1], g_iFragileMessage2[ST_MAXTYPES + 1], g_iHumanAbility[ST_MAXTYPES + 1], g_iHumanAbility2[ST_MAXTYPES + 1], g_iHumanAmmo[ST_MAXTYPES + 1], g_iHumanAmmo2[ST_MAXTYPES + 1], g_iHumanMode[ST_MAXTYPES + 1], g_iHumanMode2[ST_MAXTYPES + 1];

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
	LoadTranslations("common.phrases");
	LoadTranslations("super_tanks++.phrases");

	RegConsoleCmd("sm_st_fragile", cmdFragileInfo, "View information about the Fragile ability.");

	if (g_bLateLoad)
	{
		for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
		{
			if (bIsValidClient(iPlayer, ST_CHECK_INGAME|ST_CHECK_KICKQUEUE))
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

	vRemoveFragile(client);
}

public void OnMapEnd()
{
	vReset();
}

public Action cmdFragileInfo(int client, int args)
{
	if (!ST_IsCorePluginEnabled())
	{
		ReplyToCommand(client, "%s Super Tanks++\x01 is disabled.", ST_TAG4);

		return Plugin_Handled;
	}

	if (!bIsValidClient(client, ST_CHECK_INDEX|ST_CHECK_INGAME|ST_CHECK_KICKQUEUE|ST_CHECK_FAKECLIENT))
	{
		ReplyToCommand(client, "%s This command is to be used only in-game.", ST_TAG);

		return Plugin_Handled;
	}

	switch (IsVoteInProgress())
	{
		case true: ReplyToCommand(client, "%s %t", ST_TAG2, "Vote in Progress");
		case false: vFragileMenu(client, 0);
	}

	return Plugin_Handled;
}

static void vFragileMenu(int client, int item)
{
	Menu mAbilityMenu = new Menu(iFragileMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Fragile Ability Information");
	mAbilityMenu.AddItem("Status", "Status");
	mAbilityMenu.AddItem("Ammunition", "Ammunition");
	mAbilityMenu.AddItem("Buttons", "Buttons");
	mAbilityMenu.AddItem("Button Mode", "Button Mode");
	mAbilityMenu.AddItem("Cooldown", "Cooldown");
	mAbilityMenu.AddItem("Details", "Details");
	mAbilityMenu.AddItem("Duration", "Duration");
	mAbilityMenu.AddItem("Human Support", "Human Support");
	mAbilityMenu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

public int iFragileMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: ST_PrintToChat(param1, "%s %t", ST_TAG3, iFragileAbility(param1) == 0 ? "AbilityStatus1" : "AbilityStatus2");
				case 1: ST_PrintToChat(param1, "%s %t", ST_TAG3, "AbilityAmmo", iHumanAmmo(param1) - g_iFragileCount[param1], iHumanAmmo(param1));
				case 2: ST_PrintToChat(param1, "%s %t", ST_TAG3, "AbilityButtons");
				case 3: ST_PrintToChat(param1, "%s %t", ST_TAG3, iHumanMode(param1) == 0 ? "AbilityButtonMode1" : "AbilityButtonMode2");
				case 4: ST_PrintToChat(param1, "%s %t", ST_TAG3, "AbilityCooldown", flHumanCooldown(param1));
				case 5: ST_PrintToChat(param1, "%s %t", ST_TAG3, "FragileDetails");
				case 6: ST_PrintToChat(param1, "%s %t", ST_TAG3, "AbilityDuration", flFragileDuration(param1));
				case 7: ST_PrintToChat(param1, "%s %t", ST_TAG3, iHumanAbility(param1) == 0 ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
			}

			if (bIsValidClient(param1, ST_CHECK_INGAME|ST_CHECK_KICKQUEUE))
			{
				vFragileMenu(param1, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[255];
			Panel panel = view_as<Panel>(param2);
			Format(sMenuTitle, sizeof(sMenuTitle), "%T", "FragileMenu", param1);
			panel.SetTitle(sMenuTitle);
		}
		case MenuAction_DisplayItem:
		{
			char sMenuOption[255];
			switch (param2)
			{
				case 0:
				{
					Format(sMenuOption, sizeof(sMenuOption), "%T", "Status", param1);
					return RedrawMenuItem(sMenuOption);
				}
				case 1:
				{
					Format(sMenuOption, sizeof(sMenuOption), "%T", "Ammunition", param1);
					return RedrawMenuItem(sMenuOption);
				}
				case 2:
				{
					Format(sMenuOption, sizeof(sMenuOption), "%T", "Buttons", param1);
					return RedrawMenuItem(sMenuOption);
				}
				case 3:
				{
					Format(sMenuOption, sizeof(sMenuOption), "%T", "ButtonMode", param1);
					return RedrawMenuItem(sMenuOption);
				}
				case 4:
				{
					Format(sMenuOption, sizeof(sMenuOption), "%T", "Cooldown", param1);
					return RedrawMenuItem(sMenuOption);
				}
				case 5:
				{
					Format(sMenuOption, sizeof(sMenuOption), "%T", "Details", param1);
					return RedrawMenuItem(sMenuOption);
				}
				case 6:
				{
					Format(sMenuOption, sizeof(sMenuOption), "%T", "Duration", param1);
					return RedrawMenuItem(sMenuOption);
				}
				case 7:
				{
					Format(sMenuOption, sizeof(sMenuOption), "%T", "HumanSupport", param1);
					return RedrawMenuItem(sMenuOption);
				}
			}
		}
	}

	return 0;
}

public void ST_OnDisplayMenu(Menu menu)
{
	menu.AddItem(ST_MENU_FRAGILE, ST_MENU_FRAGILE);
}

public void ST_OnMenuItemSelected(int client, const char[] info)
{
	if (StrEqual(info, ST_MENU_FRAGILE, false))
	{
		vFragileMenu(client, 0);
	}
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (ST_IsCorePluginEnabled() && bIsValidClient(victim, ST_CHECK_INDEX|ST_CHECK_INGAME|ST_CHECK_ALIVE|ST_CHECK_KICKQUEUE) && damage > 0.0)
	{
		if (ST_IsTankSupported(victim) && ST_IsCloneSupported(victim, g_bCloneInstalled) && g_bFragile[victim])
		{
			float flFragileBulletMultiplier = !g_bTankConfig[ST_GetTankType(victim)] ? g_flFragileBulletMultiplier[ST_GetTankType(victim)] : g_flFragileBulletMultiplier2[ST_GetTankType(victim)],
				flFragileExplosiveMultiplier = !g_bTankConfig[ST_GetTankType(victim)] ? g_flFragileExplosiveMultiplier[ST_GetTankType(victim)] : g_flFragileExplosiveMultiplier2[ST_GetTankType(victim)],
				flFragileFireMultiplier = !g_bTankConfig[ST_GetTankType(victim)] ? g_flFragileFireMultiplier[ST_GetTankType(victim)] : g_flFragileFireMultiplier2[ST_GetTankType(victim)],
				flFragileMeleeMultiplier = !g_bTankConfig[ST_GetTankType(victim)] ? g_flFragileMeleeMultiplier[ST_GetTankType(victim)] : g_flFragileMeleeMultiplier2[ST_GetTankType(victim)];
			if (damagetype & DMG_BULLET)
			{
				damage *= flFragileBulletMultiplier;
			}
			else if (damagetype & DMG_BLAST || damagetype & DMG_BLAST_SURFACE || damagetype & DMG_AIRBOAT || damagetype & DMG_PLASMA)
			{
				damage *= flFragileExplosiveMultiplier;
			}
			else if (damagetype & DMG_BURN)
			{
				damage *= flFragileFireMultiplier;
			}
			else if (damagetype & DMG_SLASH || damagetype & DMG_CLUB)
			{
				damage *= flFragileMeleeMultiplier;
			}

			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}

public void ST_OnConfigsLoaded(const char[] savepath, bool main)
{
	KeyValues kvSuperTanks = new KeyValues("Super Tanks++");
	kvSuperTanks.ImportFromFile(savepath);

	for (int iIndex = ST_GetMinType(); iIndex <= ST_GetMaxType(); iIndex++)
	{
		char sTankName[33];
		Format(sTankName, sizeof(sTankName), "Tank #%i", iIndex);
		if (kvSuperTanks.JumpToKey(sTankName))
		{
			switch (main)
			{
				case true:
				{
					g_bTankConfig[iIndex] = false;

					g_iHumanAbility[iIndex] = kvSuperTanks.GetNum("Fragile Ability/Human Ability", 0);
					g_iHumanAbility[iIndex] = iClamp(g_iHumanAbility[iIndex], 0, 1);
					g_iHumanAmmo[iIndex] = kvSuperTanks.GetNum("Fragile Ability/Human Ammo", 5);
					g_iHumanAmmo[iIndex] = iClamp(g_iHumanAmmo[iIndex], 0, 9999999999);
					g_flHumanCooldown[iIndex] = kvSuperTanks.GetFloat("Fragile Ability/Human Cooldown", 30.0);
					g_flHumanCooldown[iIndex] = flClamp(g_flHumanCooldown[iIndex], 0.0, 9999999999.0);
					g_iHumanMode[iIndex] = kvSuperTanks.GetNum("Fragile Ability/Human Mode", 1);
					g_iHumanMode[iIndex] = iClamp(g_iHumanMode[iIndex], 0, 1);
					g_iFragileAbility[iIndex] = kvSuperTanks.GetNum("Fragile Ability/Ability Enabled", 0);
					g_iFragileAbility[iIndex] = iClamp(g_iFragileAbility[iIndex], 0, 1);
					g_iFragileMessage[iIndex] = kvSuperTanks.GetNum("Fragile Ability/Ability Message", 0);
					g_iFragileMessage[iIndex] = iClamp(g_iFragileMessage[iIndex], 0, 1);
					g_flFragileBulletMultiplier[iIndex] = kvSuperTanks.GetFloat("Fragile Ability/Fragile Bullet Multiplier", 5.0);
					g_flFragileBulletMultiplier[iIndex] = flClamp(g_flFragileBulletMultiplier[iIndex], 1.0, 9999999999.0);
					g_flFragileChance[iIndex] = kvSuperTanks.GetFloat("Fragile Ability/Fragile Chance", 33.3);
					g_flFragileChance[iIndex] = flClamp(g_flFragileChance[iIndex], 0.0, 100.0);
					g_flFragileDuration[iIndex] = kvSuperTanks.GetFloat("Fragile Ability/Fragile Duration", 5.0);
					g_flFragileDuration[iIndex] = flClamp(g_flFragileDuration[iIndex], 0.1, 9999999999.0);
					g_flFragileExplosiveMultiplier[iIndex] = kvSuperTanks.GetFloat("Fragile Ability/Fragile Explosive Multiplier", 5.0);
					g_flFragileExplosiveMultiplier[iIndex] = flClamp(g_flFragileExplosiveMultiplier[iIndex], 1.0, 9999999999.0);
					g_flFragileFireMultiplier[iIndex] = kvSuperTanks.GetFloat("Fragile Ability/Fragile Fire Multiplier", 3.0);
					g_flFragileFireMultiplier[iIndex] = flClamp(g_flFragileFireMultiplier[iIndex], 1.0, 9999999999.0);
					g_flFragileMeleeMultiplier[iIndex] = kvSuperTanks.GetFloat("Fragile Ability/Fragile Melee Multiplier", 1.5);
					g_flFragileMeleeMultiplier[iIndex] = flClamp(g_flFragileMeleeMultiplier[iIndex], 1.0, 9999999999.0);
				}
				case false:
				{
					g_bTankConfig[iIndex] = true;

					g_iHumanAbility2[iIndex] = kvSuperTanks.GetNum("Fragile Ability/Human Ability", g_iHumanAbility[iIndex]);
					g_iHumanAbility2[iIndex] = iClamp(g_iHumanAbility2[iIndex], 0, 1);
					g_iHumanAmmo2[iIndex] = kvSuperTanks.GetNum("Fragile Ability/Human Ammo", g_iHumanAmmo[iIndex]);
					g_iHumanAmmo2[iIndex] = iClamp(g_iHumanAmmo2[iIndex], 0, 9999999999);
					g_flHumanCooldown2[iIndex] = kvSuperTanks.GetFloat("Fragile Ability/Human Cooldown", g_flHumanCooldown[iIndex]);
					g_flHumanCooldown2[iIndex] = flClamp(g_flHumanCooldown2[iIndex], 0.0, 9999999999.0);
					g_iHumanMode2[iIndex] = kvSuperTanks.GetNum("Fragile Ability/Human Mode", g_iHumanMode[iIndex]);
					g_iHumanMode2[iIndex] = iClamp(g_iHumanMode2[iIndex], 0, 1);
					g_iFragileAbility2[iIndex] = kvSuperTanks.GetNum("Fragile Ability/Ability Enabled", g_iFragileAbility[iIndex]);
					g_iFragileAbility2[iIndex] = iClamp(g_iFragileAbility2[iIndex], 0, 1);
					g_iFragileMessage2[iIndex] = kvSuperTanks.GetNum("Fragile Ability/Ability Message", g_iFragileMessage[iIndex]);
					g_iFragileMessage2[iIndex] = iClamp(g_iFragileMessage2[iIndex], 0, 1);
					g_flFragileBulletMultiplier2[iIndex] = kvSuperTanks.GetFloat("Fragile Ability/Fragile Bullet Multiplier", g_flFragileBulletMultiplier[iIndex]);
					g_flFragileBulletMultiplier2[iIndex] = flClamp(g_flFragileBulletMultiplier2[iIndex], 1.0, 9999999999.0);
					g_flFragileChance2[iIndex] = kvSuperTanks.GetFloat("Fragile Ability/Fragile Chance", g_flFragileChance[iIndex]);
					g_flFragileChance2[iIndex] = flClamp(g_flFragileChance2[iIndex], 0.0, 100.0);
					g_flFragileDuration2[iIndex] = kvSuperTanks.GetFloat("Fragile Ability/Fragile Duration", g_flFragileDuration[iIndex]);
					g_flFragileDuration2[iIndex] = flClamp(g_flFragileDuration2[iIndex], 0.1, 9999999999.0);
					g_flFragileExplosiveMultiplier2[iIndex] = kvSuperTanks.GetFloat("Fragile Ability/Fragile Explosive Multiplier", g_flFragileExplosiveMultiplier[iIndex]);
					g_flFragileExplosiveMultiplier2[iIndex] = flClamp(g_flFragileExplosiveMultiplier2[iIndex], 1.0, 9999999999.0);
					g_flFragileFireMultiplier2[iIndex] = kvSuperTanks.GetFloat("Fragile Ability/Fragile Fire Multiplier", g_flFragileFireMultiplier[iIndex]);
					g_flFragileFireMultiplier2[iIndex] = flClamp(g_flFragileFireMultiplier2[iIndex], 1.0, 9999999999.0);
					g_flFragileMeleeMultiplier2[iIndex] = kvSuperTanks.GetFloat("Fragile Ability/Fragile Melee Multiplier", g_flFragileMeleeMultiplier[iIndex]);
					g_flFragileMeleeMultiplier2[iIndex] = flClamp(g_flFragileMeleeMultiplier2[iIndex], 1.0, 9999999999.0);
				}
			}

			kvSuperTanks.Rewind();
		}
	}

	delete kvSuperTanks;
}

public void ST_OnEventFired(Event event, const char[] name, bool dontBroadcast)
{
	if (StrEqual(name, "player_incapacitated"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (ST_IsTankSupported(iTank, ST_CHECK_INDEX|ST_CHECK_INGAME|ST_CHECK_KICKQUEUE))
		{
			vRemoveFragile(iTank);
		}
	}
}

public void ST_OnAbilityActivated(int tank)
{
	if (ST_IsTankSupported(tank) && (!ST_IsTankSupported(tank, ST_CHECK_FAKECLIENT) || iHumanAbility(tank) == 0) && ST_IsCloneSupported(tank, g_bCloneInstalled) && iFragileAbility(tank) == 1 && !g_bFragile[tank])
	{
		vFragileAbility(tank);
	}
}

public void ST_OnButtonPressed(int tank, int button)
{
	if (ST_IsTankSupported(tank, ST_CHECK_INDEX|ST_CHECK_INGAME|ST_CHECK_ALIVE|ST_CHECK_KICKQUEUE|ST_CHECK_FAKECLIENT) && ST_IsCloneSupported(tank, g_bCloneInstalled))
	{
		if (button & ST_MAIN_KEY == ST_MAIN_KEY)
		{
			if (iFragileAbility(tank) == 1 && iHumanAbility(tank) == 1)
			{
				switch (iHumanMode(tank))
				{
					case 0:
					{
						if (!g_bFragile[tank] && !g_bFragile2[tank])
						{
							vFragileAbility(tank);
						}
						else if (g_bFragile[tank])
						{
							ST_PrintToChat(tank, "%s %t", ST_TAG3, "FragileHuman3");
						}
						else if (g_bFragile2[tank])
						{
							ST_PrintToChat(tank, "%s %t", ST_TAG3, "FragileHuman4");
						}
					}
					case 1:
					{
						if (g_iFragileCount[tank] < iHumanAmmo(tank) && iHumanAmmo(tank) > 0)
						{
							if (!g_bFragile[tank] && !g_bFragile2[tank])
							{
								g_bFragile[tank] = true;
								g_iFragileCount[tank]++;

								ST_PrintToChat(tank, "%s %t", ST_TAG3, "FragileHuman", g_iFragileCount[tank], iHumanAmmo(tank));
							}
						}
						else
						{
							ST_PrintToChat(tank, "%s %t", ST_TAG3, "FragileAmmo");
						}
					}
				}
			}
		}
	}
}

public void ST_OnButtonReleased(int tank, int button)
{
	if (ST_IsTankSupported(tank, ST_CHECK_INDEX|ST_CHECK_INGAME|ST_CHECK_ALIVE|ST_CHECK_KICKQUEUE|ST_CHECK_FAKECLIENT) && ST_IsCloneSupported(tank, g_bCloneInstalled))
	{
		if (button & ST_MAIN_KEY == ST_MAIN_KEY)
		{
			if (iFragileAbility(tank) == 1 && iHumanAbility(tank) == 1)
			{
				if (iHumanMode(tank) == 1 && g_bFragile[tank] && !g_bFragile2[tank])
				{
					g_bFragile[tank] = false;

					vReset2(tank);
				}
			}
		}
	}
}

public void ST_OnChangeType(int tank)
{
	vRemoveFragile(tank);
}

static void vFragileAbility(int tank)
{
	if (g_iFragileCount[tank] < iHumanAmmo(tank) && iHumanAmmo(tank) > 0)
	{
		float flFragileChance = !g_bTankConfig[ST_GetTankType(tank)] ? g_flFragileChance[ST_GetTankType(tank)] : g_flFragileChance2[ST_GetTankType(tank)];
		if (GetRandomFloat(0.1, 100.0) <= flFragileChance)
		{
			g_bFragile[tank] = true;

			CreateTimer(flFragileDuration(tank), tTimerStopFragile, GetClientUserId(tank), TIMER_FLAG_NO_MAPCHANGE);

			if (ST_IsTankSupported(tank, ST_CHECK_FAKECLIENT) && iHumanAbility(tank) == 1)
			{
				g_iFragileCount[tank]++;

				ST_PrintToChat(tank, "%s %t", ST_TAG3, "FragileHuman", g_iFragileCount[tank], iHumanAmmo(tank));
			}

			if (iFragileMessage(tank) == 1)
			{
				char sTankName[33];
				ST_GetTankName(tank, sTankName);
				ST_PrintToChatAll("%s %t", ST_TAG2, "Fragile", sTankName);
			}
		}
		else if (ST_IsTankSupported(tank, ST_CHECK_FAKECLIENT) && iHumanAbility(tank) == 1)
		{
			ST_PrintToChat(tank, "%s %t", ST_TAG3, "FragileHuman2");
		}
	}
	else if (ST_IsTankSupported(tank, ST_CHECK_FAKECLIENT) && iHumanAbility(tank) == 1)
	{
		ST_PrintToChat(tank, "%s %t", ST_TAG3, "FragileAmmo");
	}
}

static void vRemoveFragile(int tank)
{
	g_bFragile[tank] = false;
	g_bFragile2[tank] = false;
	g_iFragileCount[tank] = 0;
}

static void vReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, ST_CHECK_INGAME|ST_CHECK_KICKQUEUE))
		{
			vRemoveFragile(iPlayer);
		}
	}
}

static void vReset2(int tank)
{
	g_bFragile2[tank] = true;

	ST_PrintToChat(tank, "%s %t", ST_TAG3, "FragileHuman5");

	if (g_iFragileCount[tank] < iHumanAmmo(tank) && iHumanAmmo(tank) > 0)
	{
		CreateTimer(flHumanCooldown(tank), tTimerResetCooldown, GetClientUserId(tank), TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		g_bFragile2[tank] = false;
	}
}

static float flFragileDuration(int tank)
{
	return !g_bTankConfig[ST_GetTankType(tank)] ? g_flFragileDuration[ST_GetTankType(tank)] : g_flFragileDuration2[ST_GetTankType(tank)];
}

static float flHumanCooldown(int tank)
{
	return !g_bTankConfig[ST_GetTankType(tank)] ? g_flHumanCooldown[ST_GetTankType(tank)] : g_flHumanCooldown2[ST_GetTankType(tank)];
}

static int iFragileAbility(int tank)
{
	return !g_bTankConfig[ST_GetTankType(tank)] ? g_iFragileAbility[ST_GetTankType(tank)] : g_iFragileAbility2[ST_GetTankType(tank)];
}

static int iFragileMessage(int tank)
{
	return !g_bTankConfig[ST_GetTankType(tank)] ? g_iFragileMessage[ST_GetTankType(tank)] : g_iFragileMessage2[ST_GetTankType(tank)];
}

static int iHumanAbility(int tank)
{
	return !g_bTankConfig[ST_GetTankType(tank)] ? g_iHumanAbility[ST_GetTankType(tank)] : g_iHumanAbility2[ST_GetTankType(tank)];
}

static int iHumanAmmo(int tank)
{
	return !g_bTankConfig[ST_GetTankType(tank)] ? g_iHumanAmmo[ST_GetTankType(tank)] : g_iHumanAmmo2[ST_GetTankType(tank)];
}

static int iHumanMode(int tank)
{
	return !g_bTankConfig[ST_GetTankType(tank)] ? g_iHumanMode[ST_GetTankType(tank)] : g_iHumanMode2[ST_GetTankType(tank)];
}

public Action tTimerStopFragile(Handle timer, int userid)
{
	int iTank = GetClientOfUserId(userid);
	if (!ST_IsTankSupported(iTank) || !ST_IsCloneSupported(iTank, g_bCloneInstalled) || !g_bFragile[iTank])
	{
		g_bFragile[iTank] = false;

		return Plugin_Stop;
	}

	g_bFragile[iTank] = false;

	if (ST_IsTankSupported(iTank, ST_CHECK_FAKECLIENT) && iHumanAbility(iTank) == 1 && !g_bFragile2[iTank])
	{
		vReset2(iTank);
	}

	if (iFragileMessage(iTank) == 1)
	{
		char sTankName[33];
		ST_GetTankName(iTank, sTankName);
		ST_PrintToChatAll("%s %t", ST_TAG2, "Fragile2", sTankName);
	}

	return Plugin_Continue;
}

public Action tTimerResetCooldown(Handle timer, int userid)
{
	int iTank = GetClientOfUserId(userid);
	if (!ST_IsTankSupported(iTank, ST_CHECK_INDEX|ST_CHECK_INGAME|ST_CHECK_ALIVE|ST_CHECK_KICKQUEUE|ST_CHECK_FAKECLIENT) || !ST_IsCloneSupported(iTank, g_bCloneInstalled) || !g_bFragile2[iTank])
	{
		g_bFragile2[iTank] = false;

		return Plugin_Stop;
	}

	g_bFragile2[iTank] = false;

	ST_PrintToChat(iTank, "%s %t", ST_TAG3, "FragileHuman6");

	return Plugin_Continue;
}