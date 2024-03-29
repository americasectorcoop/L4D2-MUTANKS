/**
 * Mutant Tanks: a L4D/L4D2 SourceMod Plugin
 * Copyright (C) 2020  Alfred "Crasher_3637/Psyk0tik" Llagas
 *
 * This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
 **/

#include <sourcemod>
#include <sdkhooks>
#include <mutant_tanks>

#undef REQUIRE_PLUGIN
#tryinclude <mt_clone>
#define REQUIRE_PLUGIN

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "[MT] Fling Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank flings survivors high into the air.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bLateLoad;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (!bIsValidGame(false) && !bIsValidGame())
	{
		strcopy(error, err_max, "\"[MT] Fling Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	g_bLateLoad = late;

	return APLRes_Success;
}

#define PARTICLE_BLOOD "boomer_explode_D"

#define MT_MENU_FLING "Fling Ability"

enum struct esGeneralSettings
{
	bool g_bCloneInstalled;

	Handle g_hSDKFlingPlayer;
	Handle g_hSDKPukePlayer;
}

esGeneralSettings g_esGeneral;

enum struct esPlayerSettings
{
	bool g_bFling;
	bool g_bFling2;
	bool g_bFling3;

	int g_iAccessFlags2;
	int g_iFlingCount;
	int g_iImmunityFlags2;
}

esPlayerSettings g_esPlayer[MAXPLAYERS + 1];

enum struct esAbilitySettings
{
	float g_flFlingChance;
	float g_flFlingDeathChance;
	float g_flFlingDeathRange;
	float g_flFlingForce;
	float g_flFlingRange;
	float g_flFlingRangeChance;
	float g_flHumanCooldown;

	int g_iAccessFlags;
	int g_iFlingAbility;
	int g_iFlingDeath;
	int g_iFlingEffect;
	int g_iFlingHit;
	int g_iFlingHitMode;
	int g_iFlingMessage;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iImmunityFlags;
}

esAbilitySettings g_esAbility[MT_MAXTYPES + 1];

public void OnAllPluginsLoaded()
{
	g_esGeneral.g_bCloneInstalled = LibraryExists("mt_clone");
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "mt_clone", false))
	{
		g_esGeneral.g_bCloneInstalled = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "mt_clone", false))
	{
		g_esGeneral.g_bCloneInstalled = false;
	}
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");

	RegConsoleCmd("sm_mt_fling", cmdFlingInfo, "View information about the Fling ability.");

	GameData gdMutantTanks = new GameData("mutant_tanks");

	if (gdMutantTanks == null)
	{
		SetFailState("Unable to load the \"mutant_tanks\" gamedata file.");

		return;
	}

	switch (bIsValidGame())
	{
		case true:
		{
			StartPrepSDKCall(SDKCall_Player);
			if (!PrepSDKCall_SetFromConf(gdMutantTanks, SDKConf_Signature, "CTerrorPlayer_Fling"))
			{
				SetFailState("Failed to find signature: CTerrorPlayer_Fling");
			}

			PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
			PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
			PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
			PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
			g_esGeneral.g_hSDKFlingPlayer = EndPrepSDKCall();

			if (g_esGeneral.g_hSDKFlingPlayer == null)
			{
				PrintToServer("%s Your \"CTerrorPlayer_Fling\" signature is outdated.", MT_TAG);
			}
		}
		case false:
		{
			StartPrepSDKCall(SDKCall_Player);
			if (!PrepSDKCall_SetFromConf(gdMutantTanks, SDKConf_Signature, "CTerrorPlayer_OnVomitedUpon"))
			{
				SetFailState("Failed to find signature: CTerrorPlayer_OnVomitedUpon");
			}

			PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
			PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
			g_esGeneral.g_hSDKPukePlayer = EndPrepSDKCall();

			if (g_esGeneral.g_hSDKPukePlayer == null)
			{
				PrintToServer("%s Your \"CTerrorPlayer_OnVomitedUpon\" signature is outdated.", MT_TAG);
			}
		}
	}

	delete gdMutantTanks;

	if (g_bLateLoad)
	{
		for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
		{
			if (bIsValidClient(iPlayer, MT_CHECK_INGAME|MT_CHECK_INKICKQUEUE))
			{
				OnClientPutInServer(iPlayer);
			}
		}

		g_bLateLoad = false;
	}
}

public void OnMapStart()
{
	vPrecacheParticle(PARTICLE_BLOOD);

	vReset();
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);

	vRemoveFling(client);
}

public void OnClientDisconnect_Post(int client)
{
	vRemoveFling(client);
}

public void OnMapEnd()
{
	vReset();
}

public Action cmdFlingInfo(int client, int args)
{
	if (!MT_IsCorePluginEnabled())
	{
		ReplyToCommand(client, "%s Mutant Tanks\x01 is disabled.", MT_TAG4);

		return Plugin_Handled;
	}

	if (!bIsValidClient(client, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_INKICKQUEUE|MT_CHECK_FAKECLIENT))
	{
		ReplyToCommand(client, "%s This command is to be used only in-game.", MT_TAG);

		return Plugin_Handled;
	}

	switch (IsVoteInProgress())
	{
		case true: ReplyToCommand(client, "%s %t", MT_TAG2, "Vote in Progress");
		case false: vFlingMenu(client, 0);
	}

	return Plugin_Handled;
}

static void vFlingMenu(int client, int item)
{
	Menu mAbilityMenu = new Menu(iFlingMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Fling Ability Information");
	mAbilityMenu.AddItem("Status", "Status");
	mAbilityMenu.AddItem("Ammunition", "Ammunition");
	mAbilityMenu.AddItem("Buttons", "Buttons");
	mAbilityMenu.AddItem("Cooldown", "Cooldown");
	mAbilityMenu.AddItem("Details", "Details");
	mAbilityMenu.AddItem("Human Support", "Human Support");
	mAbilityMenu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

public int iFlingMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, g_esAbility[MT_GetTankType(param1)].g_iFlingAbility == 0 ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", g_esAbility[MT_GetTankType(param1)].g_iHumanAmmo - g_esPlayer[param1].g_iFlingCount, g_esAbility[MT_GetTankType(param1)].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons2");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", g_esAbility[MT_GetTankType(param1)].g_flHumanCooldown);
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "FlingDetails");
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, g_esAbility[MT_GetTankType(param1)].g_iHumanAbility == 0 ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME|MT_CHECK_INKICKQUEUE))
			{
				vFlingMenu(param1, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[255];
			Panel panel = view_as<Panel>(param2);
			Format(sMenuTitle, sizeof(sMenuTitle), "%T", "FlingMenu", param1);
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
					Format(sMenuOption, sizeof(sMenuOption), "%T", "Cooldown", param1);

					return RedrawMenuItem(sMenuOption);
				}
				case 4:
				{
					Format(sMenuOption, sizeof(sMenuOption), "%T", "Details", param1);

					return RedrawMenuItem(sMenuOption);
				}
				case 5:
				{
					Format(sMenuOption, sizeof(sMenuOption), "%T", "HumanSupport", param1);

					return RedrawMenuItem(sMenuOption);
				}
			}
		}
	}

	return 0;
}

public void MT_OnDisplayMenu(Menu menu)
{
	menu.AddItem(MT_MENU_FLING, MT_MENU_FLING);
}

public void MT_OnMenuItemSelected(int client, const char[] info)
{
	if (StrEqual(info, MT_MENU_FLING, false))
	{
		vFlingMenu(client, 0);
	}
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (MT_IsCorePluginEnabled() && bIsValidClient(victim, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_INKICKQUEUE) && damage >= 0.5)
	{
		char sClassname[32];
		GetEntityClassname(inflictor, sClassname, sizeof(sClassname));
		if (MT_IsTankSupported(attacker) && bIsCloneAllowed(attacker, g_esGeneral.g_bCloneInstalled) && (g_esAbility[MT_GetTankType(attacker)].g_iFlingHitMode == 0 || g_esAbility[MT_GetTankType(attacker)].g_iFlingHitMode == 1) && bIsSurvivor(victim))
		{
			if ((!MT_HasAdminAccess(attacker) && !bHasAdminAccess(attacker)) || MT_IsAdminImmune(victim, attacker) || bIsAdminImmune(victim, attacker))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname, "weapon_tank_claw") || StrEqual(sClassname, "tank_rock"))
			{
				vFlingHit(victim, attacker, g_esAbility[MT_GetTankType(attacker)].g_flFlingChance, g_esAbility[MT_GetTankType(attacker)].g_iFlingHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW);
			}
		}
		else if (MT_IsTankSupported(victim) && bIsCloneAllowed(victim, g_esGeneral.g_bCloneInstalled) && (g_esAbility[MT_GetTankType(victim)].g_iFlingHitMode == 0 || g_esAbility[MT_GetTankType(victim)].g_iFlingHitMode == 2) && bIsSurvivor(attacker))
		{
			if ((!MT_HasAdminAccess(victim) && !bHasAdminAccess(victim)) || MT_IsAdminImmune(attacker, victim) || bIsAdminImmune(attacker, victim))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname, "weapon_melee"))
			{
				vFlingHit(attacker, victim, g_esAbility[MT_GetTankType(victim)].g_flFlingChance, g_esAbility[MT_GetTankType(victim)].g_iFlingHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE);
			}
		}
	}

	return Plugin_Continue;
}

public void MT_OnPluginCheck(ArrayList &list)
{
	char sName[32];
	GetPluginFilename(null, sName, sizeof(sName));
	list.PushString(sName);
}

public void MT_OnAbilityCheck(ArrayList &list, ArrayList &list2, ArrayList &list3, ArrayList &list4)
{
	list.PushString("flingability");
	list2.PushString("fling ability");
	list3.PushString("fling_ability");
	list4.PushString("fling");
}

public void MT_OnConfigsLoad(int mode)
{
	if (mode == 3)
	{
		for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
		{
			if (bIsValidClient(iPlayer))
			{
				g_esPlayer[iPlayer].g_iAccessFlags2 = 0;
				g_esPlayer[iPlayer].g_iImmunityFlags2 = 0;
			}
		}
	}
	else if (mode == 1)
	{
		for (int iIndex = MT_GetMinType(); iIndex <= MT_GetMaxType(); iIndex++)
		{
			g_esAbility[iIndex].g_iAccessFlags = 0;
			g_esAbility[iIndex].g_iImmunityFlags = 0;
			g_esAbility[iIndex].g_iHumanAbility = 0;
			g_esAbility[iIndex].g_iHumanAmmo = 5;
			g_esAbility[iIndex].g_flHumanCooldown = 30.0;
			g_esAbility[iIndex].g_iFlingAbility = 0;
			g_esAbility[iIndex].g_iFlingEffect = 0;
			g_esAbility[iIndex].g_iFlingMessage = 0;
			g_esAbility[iIndex].g_flFlingChance = 33.3;
			g_esAbility[iIndex].g_iFlingDeath = 0;
			g_esAbility[iIndex].g_flFlingDeathChance = 33.3;
			g_esAbility[iIndex].g_flFlingDeathRange = 200.0;
			g_esAbility[iIndex].g_flFlingForce = 300.0;
			g_esAbility[iIndex].g_iFlingHit = 0;
			g_esAbility[iIndex].g_iFlingHitMode = 0;
			g_esAbility[iIndex].g_flFlingRange = 150.0;
			g_esAbility[iIndex].g_flFlingRangeChance = 15.0;
		}
	}
}

public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
{
	if (mode == 3 && bIsValidClient(admin) && value[0] != '\0')
	{
		if (StrEqual(subsection, "flingability", false) || StrEqual(subsection, "fling ability", false) || StrEqual(subsection, "fling_ability", false) || StrEqual(subsection, "fling", false))
		{
			if (StrEqual(key, "AccessFlags", false) || StrEqual(key, "Access Flags", false) || StrEqual(key, "Access_Flags", false) || StrEqual(key, "access", false))
			{
				g_esPlayer[admin].g_iAccessFlags2 = (value[0] != '\0') ? ReadFlagString(value) : g_esPlayer[admin].g_iAccessFlags2;
			}
			else if (StrEqual(key, "ImmunityFlags", false) || StrEqual(key, "Immunity Flags", false) || StrEqual(key, "Immunity_Flags", false) || StrEqual(key, "immunity", false))
			{
				g_esPlayer[admin].g_iImmunityFlags2 = (value[0] != '\0') ? ReadFlagString(value) : g_esPlayer[admin].g_iImmunityFlags2;
			}
		}
	}

	if (mode < 3 && type > 0)
	{
		g_esAbility[type].g_iHumanAbility = iGetValue(subsection, "flingability", "fling ability", "fling_ability", "fling", key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esAbility[type].g_iHumanAbility, value, 0, 2);
		g_esAbility[type].g_iHumanAmmo = iGetValue(subsection, "flingability", "fling ability", "fling_ability", "fling", key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esAbility[type].g_iHumanAmmo, value, 0, 999999);
		g_esAbility[type].g_flHumanCooldown = flGetValue(subsection, "flingability", "fling ability", "fling_ability", "fling", key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esAbility[type].g_flHumanCooldown, value, 0.0, 999999.0);
		g_esAbility[type].g_iFlingAbility = iGetValue(subsection, "flingability", "fling ability", "fling_ability", "fling", key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "enabled", g_esAbility[type].g_iFlingAbility, value, 0, 1);
		g_esAbility[type].g_iFlingEffect = iGetValue(subsection, "flingability", "fling ability", "fling_ability", "fling", key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esAbility[type].g_iFlingEffect, value, 0, 7);
		g_esAbility[type].g_iFlingMessage = iGetValue(subsection, "flingability", "fling ability", "fling_ability", "fling", key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esAbility[type].g_iFlingMessage, value, 0, 3);
		g_esAbility[type].g_flFlingChance = flGetValue(subsection, "flingability", "fling ability", "fling_ability", "fling", key, "FlingChance", "Fling Chance", "Fling_Chance", "chance", g_esAbility[type].g_flFlingChance, value, 0.0, 100.0);
		g_esAbility[type].g_iFlingDeath = iGetValue(subsection, "flingability", "fling ability", "fling_ability", "fling", key, "FlingDeath", "Fling Death", "Fling_Death", "death", g_esAbility[type].g_iFlingDeath, value, 0, 1);
		g_esAbility[type].g_flFlingDeathChance = flGetValue(subsection, "flingability", "fling ability", "fling_ability", "fling", key, "FlingDeathChance", "Fling Death Chance", "Fling_Death_Chance", "deathchance", g_esAbility[type].g_flFlingDeathChance, value, 0.0, 100.0);
		g_esAbility[type].g_flFlingDeathRange = flGetValue(subsection, "flingability", "fling ability", "fling_ability", "fling", key, "FlingDeathRange", "Fling Death Range", "Fling_Death_Range", "deathrange", g_esAbility[type].g_flFlingDeathRange, value, 1.0, 999999.0);
		g_esAbility[type].g_flFlingForce = flGetValue(subsection, "flingability", "fling ability", "fling_ability", "fling", key, "FlingForce", "Fling Force", "Fling_Force", "force", g_esAbility[type].g_flFlingForce, value, 1.0, 999999.0);
		g_esAbility[type].g_iFlingHit = iGetValue(subsection, "flingability", "fling ability", "fling_ability", "fling", key, "FlingHit", "Fling Hit", "Fling_Hit", "hit", g_esAbility[type].g_iFlingHit, value, 0, 1);
		g_esAbility[type].g_iFlingHitMode = iGetValue(subsection, "flingability", "fling ability", "fling_ability", "fling", key, "FlingHitMode", "Fling Hit Mode", "Fling_Hit_Mode", "hitmode", g_esAbility[type].g_iFlingHitMode, value, 0, 2);
		g_esAbility[type].g_flFlingRange = flGetValue(subsection, "flingability", "fling ability", "fling_ability", "fling", key, "FlingRange", "Fling Range", "Fling_Range", "range", g_esAbility[type].g_flFlingRange, value, 1.0, 999999.0);
		g_esAbility[type].g_flFlingRangeChance = flGetValue(subsection, "flingability", "fling ability", "fling_ability", "fling", key, "FlingRangeChance", "Fling Range Chance", "Fling_Range_Chance", "rangechance", g_esAbility[type].g_flFlingRangeChance, value, 0.0, 100.0);

		if (StrEqual(subsection, "flingability", false) || StrEqual(subsection, "fling ability", false) || StrEqual(subsection, "fling_ability", false) || StrEqual(subsection, "fling", false))
		{
			if (StrEqual(key, "AccessFlags", false) || StrEqual(key, "Access Flags", false) || StrEqual(key, "Access_Flags", false) || StrEqual(key, "access", false))
			{
				g_esAbility[type].g_iAccessFlags = (value[0] != '\0') ? ReadFlagString(value) : g_esAbility[type].g_iAccessFlags;
			}
			else if (StrEqual(key, "ImmunityFlags", false) || StrEqual(key, "Immunity Flags", false) || StrEqual(key, "Immunity_Flags", false) || StrEqual(key, "immunity", false))
			{
				g_esAbility[type].g_iImmunityFlags = (value[0] != '\0') ? ReadFlagString(value) : g_esAbility[type].g_iImmunityFlags;
			}
		}
	}
}

public void MT_OnEventFired(Event event, const char[] name, bool dontBroadcast)
{
	if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_INKICKQUEUE))
		{
			vRemoveFling(iTank);

			if (bIsCloneAllowed(iTank, g_esGeneral.g_bCloneInstalled) && g_esAbility[MT_GetTankType(iTank)].g_iFlingDeath == 1 && GetRandomFloat(0.1, 100.0) <= g_esAbility[MT_GetTankType(iTank)].g_flFlingDeathChance)
			{
				if (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank))
				{
					return;
				}

				if (!bIsValidGame())
				{
					vAttachParticle(iTank, PARTICLE_BLOOD, 0.1, 0.0);
				}

				float flTankPos[3];
				GetClientAbsOrigin(iTank, flTankPos);

				for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
				{
					if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_INKICKQUEUE) && !MT_IsAdminImmune(iSurvivor, iTank) && !bIsAdminImmune(iSurvivor, iTank))
					{
						float flSurvivorPos[3];
						GetClientAbsOrigin(iSurvivor, flSurvivorPos);

						float flDistance = GetVectorDistance(flTankPos, flSurvivorPos);
						if (flDistance <= g_esAbility[MT_GetTankType(iTank)].g_flFlingDeathRange)
						{
							switch (bIsValidGame())
							{
								case true: vFling(iSurvivor, iTank);
								case false: SDKCall(g_esGeneral.g_hSDKPukePlayer, iSurvivor, iTank, true);
							}
						}
					}
				}
			}
		}
	}
}

public void MT_OnAbilityActivated(int tank)
{
	if (MT_IsTankSupported(tank, MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank)) || g_esAbility[MT_GetTankType(tank)].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!MT_IsTankSupported(tank, MT_CHECK_FAKECLIENT) || g_esAbility[MT_GetTankType(tank)].g_iHumanAbility != 1) && bIsCloneAllowed(tank, g_esGeneral.g_bCloneInstalled) && g_esAbility[MT_GetTankType(tank)].g_iFlingAbility == 1)
	{
		vFlingAbility(tank);
	}
}

public void MT_OnButtonPressed(int tank, int button)
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_INKICKQUEUE|MT_CHECK_FAKECLIENT) && bIsCloneAllowed(tank, g_esGeneral.g_bCloneInstalled))
	{
		if (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank))
		{
			return;
		}

		if (button & MT_SUB_KEY == MT_SUB_KEY)
		{
			if (g_esAbility[MT_GetTankType(tank)].g_iFlingAbility == 1 && g_esAbility[MT_GetTankType(tank)].g_iHumanAbility == 1)
			{
				switch (g_esPlayer[tank].g_bFling)
				{
					case true: MT_PrintToChat(tank, "%s %t", MT_TAG3, "FlingHuman3");
					case false: vFlingAbility(tank);
				}
			}
		}
	}
}

public void MT_OnChangeType(int tank, bool revert)
{
	vRemoveFling(tank);
}

static void vFling(int survivor, int tank)
{
	float flSurvivorPos[3], flTankPos[3], flDistance[3], flRatio[3], flVelocity[3];

	GetClientAbsOrigin(survivor, flSurvivorPos);
	GetClientAbsOrigin(tank, flTankPos);

	flDistance[0] = (flTankPos[0] - flSurvivorPos[0]);
	flDistance[1] = (flTankPos[1] - flSurvivorPos[1]);
	flDistance[2] = (flTankPos[2] - flSurvivorPos[2]);

	flRatio[0] = flDistance[0] / (SquareRoot((flDistance[1] * flDistance[1]) + (flDistance[0] * flDistance[0])));
	flRatio[1] = flDistance[1] / (SquareRoot((flDistance[1] * flDistance[1]) + (flDistance[0] * flDistance[0])));

	flVelocity[0] = (flRatio[0] * -1) * g_esAbility[MT_GetTankType(tank)].g_flFlingForce;
	flVelocity[1] = (flRatio[1] * -1) * g_esAbility[MT_GetTankType(tank)].g_flFlingForce;
	flVelocity[2] = g_esAbility[MT_GetTankType(tank)].g_flFlingForce;

	SDKCall(g_esGeneral.g_hSDKFlingPlayer, survivor, flVelocity, 76, tank, 3.0);
}

static void vFlingAbility(int tank)
{
	if (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank))
	{
		return;
	}

	if (!MT_IsTankSupported(tank, MT_CHECK_FAKECLIENT) || (g_esPlayer[tank].g_iFlingCount < g_esAbility[MT_GetTankType(tank)].g_iHumanAmmo && g_esAbility[MT_GetTankType(tank)].g_iHumanAmmo > 0))
	{
		g_esPlayer[tank].g_bFling2 = false;
		g_esPlayer[tank].g_bFling3 = false;

		float flTankPos[3];
		GetClientAbsOrigin(tank, flTankPos);

		int iSurvivorCount;
		for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
		{
			if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_INKICKQUEUE) && !MT_IsAdminImmune(iSurvivor, tank) && !bIsAdminImmune(iSurvivor, tank))
			{
				float flSurvivorPos[3];
				GetClientAbsOrigin(iSurvivor, flSurvivorPos);

				float flDistance = GetVectorDistance(flTankPos, flSurvivorPos);
				if (flDistance <= g_esAbility[MT_GetTankType(tank)].g_flFlingRange)
				{
					vFlingHit(iSurvivor, tank, g_esAbility[MT_GetTankType(tank)].g_flFlingRangeChance, g_esAbility[MT_GetTankType(tank)].g_iFlingAbility, MT_MESSAGE_RANGE, MT_ATTACK_RANGE);

					iSurvivorCount++;
				}
			}
		}

		if (iSurvivorCount == 0)
		{
			if (MT_IsTankSupported(tank, MT_CHECK_FAKECLIENT) && g_esAbility[MT_GetTankType(tank)].g_iHumanAbility == 1)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "FlingHuman4");
			}
		}
	}
	else if (MT_IsTankSupported(tank, MT_CHECK_FAKECLIENT) && g_esAbility[MT_GetTankType(tank)].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "FlingAmmo");
	}
}

static void vFlingHit(int survivor, int tank, float chance, int enabled, int messages, int flags)
{
	if ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank)) || MT_IsAdminImmune(survivor, tank) || bIsAdminImmune(survivor, tank))
	{
		return;
	}

	if (enabled == 1 && bIsSurvivor(survivor))
	{
		if (!MT_IsTankSupported(tank, MT_CHECK_FAKECLIENT) || (g_esPlayer[tank].g_iFlingCount < g_esAbility[MT_GetTankType(tank)].g_iHumanAmmo && g_esAbility[MT_GetTankType(tank)].g_iHumanAmmo > 0))
		{
			if (GetRandomFloat(0.1, 100.0) <= chance)
			{
				if (MT_IsTankSupported(tank, MT_CHECK_FAKECLIENT) && g_esAbility[MT_GetTankType(tank)].g_iHumanAbility == 1 && (flags & MT_ATTACK_RANGE) && !g_esPlayer[tank].g_bFling)
				{
					g_esPlayer[tank].g_bFling = true;
					g_esPlayer[tank].g_iFlingCount++;

					MT_PrintToChat(tank, "%s %t", MT_TAG3, "FlingHuman", g_esPlayer[tank].g_iFlingCount, g_esAbility[MT_GetTankType(tank)].g_iHumanAmmo);

					if (g_esPlayer[tank].g_iFlingCount < g_esAbility[MT_GetTankType(tank)].g_iHumanAmmo && g_esAbility[MT_GetTankType(tank)].g_iHumanAmmo > 0)
					{
						CreateTimer(g_esAbility[MT_GetTankType(tank)].g_flHumanCooldown, tTimerResetCooldown, GetClientUserId(tank), TIMER_FLAG_NO_MAPCHANGE);
					}
					else
					{
						g_esPlayer[tank].g_bFling = false;
					}
				}

				vEffect(survivor, tank, g_esAbility[MT_GetTankType(tank)].g_iFlingEffect, flags);

				char sTankName[33];
				MT_GetTankName(tank, MT_GetTankType(tank), sTankName);

				switch (bIsValidGame())
				{
					case true:
					{
						vFling(survivor, tank);

						if (g_esAbility[MT_GetTankType(tank)].g_iFlingMessage & messages)
						{
							MT_PrintToChatAll("%s %t", MT_TAG2, "Fling", sTankName, survivor);
						}
					}
					case false:
					{
						SDKCall(g_esGeneral.g_hSDKPukePlayer, survivor, tank, true);

						if (g_esAbility[MT_GetTankType(tank)].g_iFlingMessage & messages)
						{
							MT_PrintToChatAll("%s %t", MT_TAG2, "Puke", sTankName, survivor);
						}
					}
				}
			}
			else if ((flags & MT_ATTACK_RANGE) && !g_esPlayer[tank].g_bFling)
			{
				if (MT_IsTankSupported(tank, MT_CHECK_FAKECLIENT) && g_esAbility[MT_GetTankType(tank)].g_iHumanAbility == 1 && !g_esPlayer[tank].g_bFling2)
				{
					g_esPlayer[tank].g_bFling2 = true;

					MT_PrintToChat(tank, "%s %t", MT_TAG3, "FlingHuman2");
				}
			}
		}
		else if (MT_IsTankSupported(tank, MT_CHECK_FAKECLIENT) && g_esAbility[MT_GetTankType(tank)].g_iHumanAbility == 1 && !g_esPlayer[tank].g_bFling3)
		{
			g_esPlayer[tank].g_bFling3 = true;

			MT_PrintToChat(tank, "%s %t", MT_TAG3, "FlingAmmo");
		}
	}
}

static void vRemoveFling(int tank)
{
	g_esPlayer[tank].g_bFling = false;
	g_esPlayer[tank].g_bFling2 = false;
	g_esPlayer[tank].g_bFling3 = false;
	g_esPlayer[tank].g_iFlingCount = 0;
}

static void vReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME|MT_CHECK_INKICKQUEUE))
		{
			vRemoveFling(iPlayer);
		}
	}
}

static bool bHasAdminAccess(int admin)
{
	if (!bIsValidClient(admin, MT_CHECK_FAKECLIENT))
	{
		return true;
	}

	int iAbilityFlags = g_esAbility[MT_GetTankType(admin)].g_iAccessFlags;
	if (iAbilityFlags != 0 && g_esPlayer[admin].g_iAccessFlags2 != 0)
	{
		return (!(g_esPlayer[admin].g_iAccessFlags2 & iAbilityFlags)) ? false : true;
	}

	int iTypeFlags = MT_GetAccessFlags(2, MT_GetTankType(admin));
	if (iTypeFlags != 0 && g_esPlayer[admin].g_iAccessFlags2 != 0)
	{
		return (!(g_esPlayer[admin].g_iAccessFlags2 & iTypeFlags)) ? false : true;
	}

	int iGlobalFlags = MT_GetAccessFlags(1);
	if (iGlobalFlags != 0 && g_esPlayer[admin].g_iAccessFlags2 != 0)
	{
		return (!(g_esPlayer[admin].g_iAccessFlags2 & iGlobalFlags)) ? false : true;
	}

	int iClientTypeFlags = MT_GetAccessFlags(4, MT_GetTankType(admin), admin);
	if (iClientTypeFlags != 0 && iAbilityFlags != 0)
	{
		return (!(iClientTypeFlags & iAbilityFlags)) ? false : true;
	}

	int iClientGlobalFlags = MT_GetAccessFlags(3, 0, admin);
	if (iClientGlobalFlags != 0 && iAbilityFlags != 0)
	{
		return (!(iClientGlobalFlags & iAbilityFlags)) ? false : true;
	}

	if (iAbilityFlags != 0)
	{
		return (!(GetUserFlagBits(admin) & iAbilityFlags)) ? false : true;
	}

	return true;
}

static bool bIsAdminImmune(int survivor, int tank)
{
	if (!bIsValidClient(survivor, MT_CHECK_FAKECLIENT))
	{
		return false;
	}

	int iAbilityFlags = g_esAbility[MT_GetTankType(tank)].g_iImmunityFlags;
	if (iAbilityFlags != 0 && g_esPlayer[survivor].g_iImmunityFlags2 != 0 && (g_esPlayer[survivor].g_iImmunityFlags2 & iAbilityFlags))
	{
		return (g_esPlayer[tank].g_iImmunityFlags2 != 0 && (g_esPlayer[tank].g_iImmunityFlags2 & iAbilityFlags) && g_esPlayer[survivor].g_iImmunityFlags2 <= g_esPlayer[tank].g_iImmunityFlags2) ? false : true;
	}

	int iTypeFlags = MT_GetImmunityFlags(2, MT_GetTankType(tank));
	if (iTypeFlags != 0 && g_esPlayer[survivor].g_iImmunityFlags2 != 0 && (g_esPlayer[survivor].g_iImmunityFlags2 & iTypeFlags))
	{
		return (g_esPlayer[tank].g_iImmunityFlags2 != 0 && (g_esPlayer[tank].g_iImmunityFlags2 & iAbilityFlags) && g_esPlayer[survivor].g_iImmunityFlags2 <= g_esPlayer[tank].g_iImmunityFlags2) ? false : true;
	}

	int iGlobalFlags = MT_GetImmunityFlags(1);
	if (iGlobalFlags != 0 && g_esPlayer[survivor].g_iImmunityFlags2 != 0 && (g_esPlayer[survivor].g_iImmunityFlags2 & iGlobalFlags))
	{
		return (g_esPlayer[tank].g_iImmunityFlags2 != 0 && (g_esPlayer[tank].g_iImmunityFlags2 & iAbilityFlags) && g_esPlayer[survivor].g_iImmunityFlags2 <= g_esPlayer[tank].g_iImmunityFlags2) ? false : true;
	}

	int iClientTypeFlags = MT_GetImmunityFlags(4, MT_GetTankType(tank), survivor),
		iClientTypeFlags2 = MT_GetImmunityFlags(4, MT_GetTankType(tank), tank);
	if (iClientTypeFlags != 0 && iAbilityFlags != 0 && (iClientTypeFlags & iAbilityFlags))
	{
		return (iClientTypeFlags2 != 0 && (iClientTypeFlags2 & iAbilityFlags) && iClientTypeFlags <= iClientTypeFlags2) ? false : true;
	}

	int iClientGlobalFlags = MT_GetImmunityFlags(3, 0, survivor),
		iClientGlobalFlags2 = MT_GetImmunityFlags(3, 0, tank);
	if (iClientGlobalFlags != 0 && iAbilityFlags != 0 && (iClientGlobalFlags & iAbilityFlags))
	{
		return (iClientGlobalFlags2 != 0 && (iClientGlobalFlags2 & iAbilityFlags) && iClientGlobalFlags <= iClientGlobalFlags2) ? false : true;
	}

	int iSurvivorFlags = GetUserFlagBits(survivor), iTankFlags = GetUserFlagBits(tank);
	if (iAbilityFlags != 0 && iSurvivorFlags != 0 && (iSurvivorFlags & iAbilityFlags))
	{
		return (iTankFlags != 0 && iSurvivorFlags <= iTankFlags) ? false : true;
	}

	return false;
}

public Action tTimerResetCooldown(Handle timer, int userid)
{
	int iTank = GetClientOfUserId(userid);
	if (!MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_INKICKQUEUE|MT_CHECK_FAKECLIENT) || !bIsCloneAllowed(iTank, g_esGeneral.g_bCloneInstalled) || !g_esPlayer[iTank].g_bFling)
	{
		g_esPlayer[iTank].g_bFling = false;

		return Plugin_Stop;
	}

	g_esPlayer[iTank].g_bFling = false;

	MT_PrintToChat(iTank, "%s %t", MT_TAG3, "FlingHuman5");

	return Plugin_Continue;
}