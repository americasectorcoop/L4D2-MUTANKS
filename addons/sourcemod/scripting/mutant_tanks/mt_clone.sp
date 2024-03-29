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
#include <mt_clone>
#include <mutant_tanks>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "[MT] Clone Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank creates clones of itself.",
	version = MT_VERSION,
	url = MT_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (!bIsValidGame(false) && !bIsValidGame())
	{
		strcopy(error, err_max, "\"[MT] Clone Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	CreateNative("MT_IsCloneSupported", aNative_IsCloneSupported);

	RegPluginLibrary("mt_clone");

	return APLRes_Success;
}

#define MT_MENU_CLONE "Clone Ability"

enum struct esPlayerSettings
{
	bool g_bClone;
	bool g_bClone2;
	int g_iAccessFlags2;
	int g_iCloneCount;
	int g_iCloneCount2;
	int g_iCloneOwner;
}

esPlayerSettings g_esPlayer[MAXPLAYERS + 1];

enum struct esAbilitySettings
{
	float g_flCloneChance;
	float g_flHumanCooldown;

	int g_iAccessFlags;
	int g_iCloneAbility;
	int g_iCloneAmount;
	int g_iCloneHealth;
	int g_iCloneMessage;
	int g_iCloneMode;
	int g_iCloneReplace;
	int g_iHumanAbility;
	int g_iHumanAmmo;
}

esAbilitySettings g_esAbility[MT_MAXTYPES + 1];

public any aNative_IsCloneSupported(Handle plugin, int numParams)
{
	int iTank = GetNativeCell(1);
	bool bCloneInstalled = GetNativeCell(2);
	if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_INKICKQUEUE))
	{
		if (bCloneInstalled && g_esAbility[MT_GetTankType(iTank)].g_iCloneMode == 0 && g_esPlayer[iTank].g_bClone)
		{
			return false;
		}
	}

	return true;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");

	RegConsoleCmd("sm_mt_clone", cmdCloneInfo, "View information about the Clone ability.");
}

public void OnMapStart()
{
	vReset();
}

public void OnClientPutInServer(int client)
{
	vRemoveClone(client);
}

public void OnClientDisconnect_Post(int client)
{
	vRemoveClone(client);
}

public void OnMapEnd()
{
	vReset();
}

public Action cmdCloneInfo(int client, int args)
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
		case false: vCloneMenu(client, 0);
	}

	return Plugin_Handled;
}

static void vCloneMenu(int client, int item)
{
	Menu mAbilityMenu = new Menu(iCloneMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Clone Ability Information");
	mAbilityMenu.AddItem("Status", "Status");
	mAbilityMenu.AddItem("Ammunition", "Ammunition");
	mAbilityMenu.AddItem("Buttons", "Buttons");
	mAbilityMenu.AddItem("Cooldown", "Cooldown");
	mAbilityMenu.AddItem("Details", "Details");
	mAbilityMenu.AddItem("Human Support", "Human Support");
	mAbilityMenu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

public int iCloneMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, g_esAbility[MT_GetTankType(param1)].g_iCloneAbility == 0 ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", g_esAbility[MT_GetTankType(param1)].g_iHumanAmmo - g_esPlayer[param1].g_iCloneCount2, g_esAbility[MT_GetTankType(param1)].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons3");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", g_esAbility[MT_GetTankType(param1)].g_flHumanCooldown);
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "CloneDetails");
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, g_esAbility[MT_GetTankType(param1)].g_iHumanAbility == 0 ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME|MT_CHECK_INKICKQUEUE))
			{
				vCloneMenu(param1, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[255];
			Panel panel = view_as<Panel>(param2);
			Format(sMenuTitle, sizeof(sMenuTitle), "%T", "CloneMenu", param1);
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
	menu.AddItem(MT_MENU_CLONE, MT_MENU_CLONE);
}

public void MT_OnMenuItemSelected(int client, const char[] info)
{
	if (StrEqual(info, MT_MENU_CLONE, false))
	{
		vCloneMenu(client, 0);
	}
}

public void MT_OnPluginCheck(ArrayList &list)
{
	char sName[32];
	GetPluginFilename(null, sName, sizeof(sName));
	list.PushString(sName);
}

public void MT_OnAbilityCheck(ArrayList &list, ArrayList &list2, ArrayList &list3, ArrayList &list4)
{
	list.PushString("cloneability");
	list2.PushString("clone ability");
	list3.PushString("clone_ability");
	list4.PushString("clone");
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
			}
		}
	}
	else if (mode == 1)
	{
		for (int iIndex = MT_GetMinType(); iIndex <= MT_GetMaxType(); iIndex++)
		{
			g_esAbility[iIndex].g_iAccessFlags = 0;
			g_esAbility[iIndex].g_iHumanAbility = 0;
			g_esAbility[iIndex].g_iHumanAmmo = 5;
			g_esAbility[iIndex].g_flHumanCooldown = 60.0;
			g_esAbility[iIndex].g_iCloneAbility = 0;
			g_esAbility[iIndex].g_iCloneMessage = 0;
			g_esAbility[iIndex].g_iCloneAmount = 2;
			g_esAbility[iIndex].g_flCloneChance = 33.3;
			g_esAbility[iIndex].g_iCloneHealth = 1000;
			g_esAbility[iIndex].g_iCloneMode = 0;
			g_esAbility[iIndex].g_iCloneReplace = 1;
		}
	}
}

public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
{
	if (mode == 3 && bIsValidClient(admin) && value[0] != '\0')
	{
		if (StrEqual(subsection, "cloneability", false) || StrEqual(subsection, "clone ability", false) || StrEqual(subsection, "clone_ability", false) || StrEqual(subsection, "clone", false))
		{
			if (StrEqual(key, "AccessFlags", false) || StrEqual(key, "Access Flags", false) || StrEqual(key, "Access_Flags", false) || StrEqual(key, "access", false))
			{
				g_esPlayer[admin].g_iAccessFlags2 = (value[0] != '\0') ? ReadFlagString(value) : g_esPlayer[admin].g_iAccessFlags2;
			}
		}
	}

	if (mode < 3 && type > 0)
	{
		g_esAbility[type].g_iHumanAbility = iGetValue(subsection, "cloneability", "clone ability", "clone_ability", "clone", key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esAbility[type].g_iHumanAbility, value, 0, 2);
		g_esAbility[type].g_iHumanAmmo = iGetValue(subsection, "cloneability", "clone ability", "clone_ability", "clone", key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esAbility[type].g_iHumanAmmo, value, 0, 999999);
		g_esAbility[type].g_flHumanCooldown = flGetValue(subsection, "cloneability", "clone ability", "clone_ability", "clone", key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esAbility[type].g_flHumanCooldown, value, 0.0, 999999.0);
		g_esAbility[type].g_iCloneAbility = iGetValue(subsection, "cloneability", "clone ability", "clone_ability", "clone", key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "enabled", g_esAbility[type].g_iCloneAbility, value, 0, 1);
		g_esAbility[type].g_iCloneMessage = iGetValue(subsection, "cloneability", "clone ability", "clone_ability", "clone", key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esAbility[type].g_iCloneMessage, value, 0, 1);
		g_esAbility[type].g_iCloneAmount = iGetValue(subsection, "cloneability", "clone ability", "clone_ability", "clone", key, "CloneAmount", "Clone Amount", "Clone_Amount", "amount", g_esAbility[type].g_iCloneAmount, value, 1, 25);
		g_esAbility[type].g_flCloneChance = flGetValue(subsection, "cloneability", "clone ability", "clone_ability", "clone", key, "CloneChance", "Clone Chance", "Clone_Chance", "chance", g_esAbility[type].g_flCloneChance, value, 0.0, 100.0);
		g_esAbility[type].g_iCloneHealth = iGetValue(subsection, "cloneability", "clone ability", "clone_ability", "clone", key, "CloneHealth", "Clone Health", "Clone_Health", "health", g_esAbility[type].g_iCloneHealth, value, 1, MT_MAXHEALTH);
		g_esAbility[type].g_iCloneMode = iGetValue(subsection, "cloneability", "clone ability", "clone_ability", "clone", key, "CloneMode", "Clone Mode", "Clone_Mode", "mode", g_esAbility[type].g_iCloneMode, value, 0, 1);
		g_esAbility[type].g_iCloneReplace = iGetValue(subsection, "cloneability", "clone ability", "clone_ability", "clone", key, "CloneReplace", "Clone Replace", "Clone_Replace", "replace", g_esAbility[type].g_iCloneReplace, value, 0, 1);

		if (StrEqual(subsection, "cloneability", false) || StrEqual(subsection, "clone ability", false) || StrEqual(subsection, "clone_ability", false) || StrEqual(subsection, "clone", false))
		{
			if (StrEqual(key, "AccessFlags", false) || StrEqual(key, "Access Flags", false) || StrEqual(key, "Access_Flags", false) || StrEqual(key, "access", false))
			{
				g_esAbility[type].g_iAccessFlags = (value[0] != '\0') ? ReadFlagString(value) : g_esAbility[type].g_iAccessFlags;
			}
		}
	}
}

public void MT_OnPluginEnd()
{
	for (int iClone = 1; iClone <= MaxClients; iClone++)
	{
		if (bIsTank(iClone, MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_INKICKQUEUE) && g_esPlayer[iClone].g_bClone)
		{
			!bIsValidClient(iClone, MT_CHECK_FAKECLIENT) ? KickClient(iClone) : ForcePlayerSuicide(iClone);
		}
	}
}

public void MT_OnEventFired(Event event, const char[] name, bool dontBroadcast)
{
	if (StrEqual(name, "player_death"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_INKICKQUEUE))
		{
			vRemoveClone(iTank, true);

			if (g_esAbility[MT_GetTankType(iTank)].g_iCloneAbility == 1)
			{
				switch (g_esPlayer[iTank].g_bClone)
				{
					case true:
					{
						for (int iOwner = 1; iOwner <= MaxClients; iOwner++)
						{
							if (MT_IsTankSupported(iOwner, MT_CHECK_INGAME|MT_CHECK_INKICKQUEUE) && g_esPlayer[iTank].g_iCloneOwner == iOwner)
							{
								g_esPlayer[iTank].g_bClone = false;
								g_esPlayer[iTank].g_iCloneOwner = 0;

								switch (g_esPlayer[iOwner].g_iCloneCount)
								{
									case 0, 1:
									{
										g_esPlayer[iOwner].g_iCloneCount = 0;

										if (MT_IsTankSupported(iOwner, MT_CHECK_FAKECLIENT) && (MT_HasAdminAccess(iOwner) || bHasAdminAccess(iOwner)) && g_esAbility[MT_GetTankType(iOwner)].g_iHumanAbility == 1)
										{
											g_esPlayer[iOwner].g_bClone2 = true;

											MT_PrintToChat(iOwner, "%s %t", MT_TAG3, "CloneHuman6");

											if (g_esAbility[MT_GetTankType(iOwner)].g_flHumanCooldown > 0.0)
											{
												CreateTimer(g_esAbility[MT_GetTankType(iOwner)].g_flHumanCooldown, tTimerResetCooldown, GetClientUserId(iOwner), TIMER_FLAG_NO_MAPCHANGE);
											}
											else
											{
												g_esPlayer[iOwner].g_bClone2 = false;
											}
										}
									}
									default:
									{
										if (g_esAbility[MT_GetTankType(iOwner)].g_iCloneReplace == 1)
										{
											g_esPlayer[iOwner].g_iCloneCount--;
										}

										if (MT_IsTankSupported(iOwner, MT_CHECK_FAKECLIENT) && g_esAbility[MT_GetTankType(iOwner)].g_iHumanAbility == 1)
										{
											MT_PrintToChat(iOwner, "%s %t", MT_TAG3, "CloneHuman5");
										}
									}
								}

								break;
							}
						}
					}
					case false:
					{
						for (int iClone = 1; iClone <= MaxClients; iClone++)
						{
							if (MT_IsTankSupported(iTank, MT_CHECK_INGAME|MT_CHECK_INKICKQUEUE) && g_esPlayer[iClone].g_iCloneOwner == iTank)
							{
								g_esPlayer[iClone].g_iCloneOwner = 0;
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

	if (MT_IsTankSupported(tank) && (!MT_IsTankSupported(tank, MT_CHECK_FAKECLIENT) || g_esAbility[MT_GetTankType(tank)].g_iHumanAbility != 1) && g_esAbility[MT_GetTankType(tank)].g_iCloneAbility == 1 && !g_esPlayer[tank].g_bClone)
	{
		vCloneAbility(tank);
	}
}

public void MT_OnButtonPressed(int tank, int button)
{
	if (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank))
	{
		return;
	}

	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_INKICKQUEUE|MT_CHECK_FAKECLIENT))
	{
		if (button & MT_SPECIAL_KEY == MT_SPECIAL_KEY)
		{
			if (g_esAbility[MT_GetTankType(tank)].g_iCloneAbility == 1 && g_esAbility[MT_GetTankType(tank)].g_iHumanAbility == 1)
			{
				if (!g_esPlayer[tank].g_bClone && !g_esPlayer[tank].g_bClone2)
				{
					vCloneAbility(tank);
				}
				else if (g_esPlayer[tank].g_bClone)
				{
					MT_PrintToChat(tank, "%s %t", MT_TAG3, "CloneHuman3");
				}
				else if (g_esPlayer[tank].g_bClone2)
				{
					MT_PrintToChat(tank, "%s %t", MT_TAG3, "CloneHuman4");
				}
			}
		}
	}
}

public void MT_OnChangeType(int tank, bool revert)
{
	vRemoveClone(tank, revert);
}

static void vCloneAbility(int tank)
{
	if (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank))
	{
		return;
	}

	if (g_esPlayer[tank].g_iCloneCount < g_esAbility[MT_GetTankType(tank)].g_iCloneAmount && (!MT_IsTankSupported(tank, MT_CHECK_FAKECLIENT) || (g_esPlayer[tank].g_iCloneCount2 < g_esAbility[MT_GetTankType(tank)].g_iHumanAmmo && g_esAbility[MT_GetTankType(tank)].g_iHumanAmmo > 0)))
	{
		if (GetRandomFloat(0.1, 100.0) <= g_esAbility[MT_GetTankType(tank)].g_flCloneChance)
		{
			float flHitPosition[3], flPosition[3], flAngles[3], flVector[3];
			GetClientEyePosition(tank, flPosition);
			GetClientEyeAngles(tank, flAngles);
			flAngles[0] = -25.0;

			GetAngleVectors(flAngles, flAngles, NULL_VECTOR, NULL_VECTOR);
			NormalizeVector(flAngles, flAngles);
			ScaleVector(flAngles, -1.0);
			vCopyVector(flAngles, flVector);
			GetVectorAngles(flAngles, flAngles);

			Handle hTrace = TR_TraceRayFilterEx(flPosition, flAngles, MASK_SOLID, RayType_Infinite, bTraceRayDontHitSelf, tank);
			if (hTrace != null)
			{
				if (TR_DidHit(hTrace))
				{
					TR_GetEndPosition(flHitPosition, hTrace);
					NormalizeVector(flVector, flVector);
					ScaleVector(flVector, -40.0);
					AddVectors(flHitPosition, flVector, flHitPosition);

					float flDistance = GetVectorDistance(flHitPosition, flPosition);
					if (flDistance < 200.0 && flDistance > 40.0)
					{
						bool bTankBoss[MAXPLAYERS + 1];
						for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
						{
							bTankBoss[iPlayer] = false;
							if (MT_IsTankSupported(iPlayer, MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_INKICKQUEUE))
							{
								bTankBoss[iPlayer] = true;
							}
						}

						MT_SpawnTank(tank, MT_GetTankType(tank));

						int iSelectedType;
						for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
						{
							if (MT_IsTankSupported(iPlayer, MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_INKICKQUEUE) && !bTankBoss[iPlayer])
							{
								iSelectedType = iPlayer;

								break;
							}
						}

						if (iSelectedType > 0)
						{
							TeleportEntity(iSelectedType, flHitPosition, NULL_VECTOR, NULL_VECTOR);

							g_esPlayer[iSelectedType].g_bClone = true;
							g_esPlayer[tank].g_iCloneCount++;
							g_esPlayer[iSelectedType].g_iCloneOwner = tank;

							int iNewHealth = (g_esAbility[MT_GetTankType(tank)].g_iCloneHealth > MT_MAXHEALTH) ? MT_MAXHEALTH : g_esAbility[MT_GetTankType(tank)].g_iCloneHealth;
							//SetEntityHealth(iSelectedType, iNewHealth);
							SetEntProp(iSelectedType, Prop_Data, "m_iHealth", iNewHealth);
							SetEntProp(iSelectedType, Prop_Data, "m_iMaxHealth", iNewHealth);

							if (MT_IsTankSupported(tank, MT_CHECK_FAKECLIENT) && g_esAbility[MT_GetTankType(tank)].g_iHumanAbility == 1)
							{
								g_esPlayer[tank].g_iCloneCount2++;

								MT_PrintToChat(tank, "%s %t", MT_TAG3, "CloneHuman", g_esPlayer[tank].g_iCloneCount2, g_esAbility[MT_GetTankType(tank)].g_iHumanAmmo);
							}

							if (g_esAbility[MT_GetTankType(tank)].g_iCloneMessage == 1)
							{
								char sTankName[33];
								MT_GetTankName(tank, MT_GetTankType(tank), sTankName);
								MT_PrintToChatAll("%s %t", MT_TAG2, "Clone", sTankName);
							}
						}
					}
				}

				delete hTrace;
			}
		}
		else if (MT_IsTankSupported(tank, MT_CHECK_FAKECLIENT) && g_esAbility[MT_GetTankType(tank)].g_iHumanAbility == 1)
		{
			MT_PrintToChat(tank, "%s %t", MT_TAG3, "CloneHuman2");
		}
	}
	else if (MT_IsTankSupported(tank, MT_CHECK_FAKECLIENT) && g_esAbility[MT_GetTankType(tank)].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "CloneAmmo");
	}
}

static void vRemoveClone(int tank, bool revert = false)
{
	if (!revert)
	{
		g_esPlayer[tank].g_bClone = false;
	}

	g_esPlayer[tank].g_bClone2 = false;
	g_esPlayer[tank].g_iCloneCount = 0;
	g_esPlayer[tank].g_iCloneCount2 = 0;
}

static void vReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME|MT_CHECK_INKICKQUEUE))
		{
			vRemoveClone(iPlayer);

			g_esPlayer[iPlayer].g_iCloneOwner = 0;
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

public Action tTimerResetCooldown(Handle timer, int userid)
{
	int iTank = GetClientOfUserId(userid);
	if (!MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_INKICKQUEUE|MT_CHECK_FAKECLIENT) || g_esPlayer[iTank].g_bClone || !g_esPlayer[iTank].g_bClone2)
	{
		g_esPlayer[iTank].g_bClone2 = false;

		return Plugin_Stop;
	}

	g_esPlayer[iTank].g_bClone2 = false;

	MT_PrintToChat(iTank, "%s %t", MT_TAG3, "CloneHuman7");

	return Plugin_Continue;
}