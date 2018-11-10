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

// Super Tanks++: Throw Ability
#include <sourcemod>
#include <sdktools>

#undef REQUIRE_PLUGIN
#include <st_clone>
#define REQUIRE_PLUGIN

#include <super_tanks++>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "[ST++] Throw Ability",
	author = ST_AUTHOR,
	description = "The Super Tank throws cars, special infected, or itself.",
	version = ST_VERSION,
	url = ST_URL
};

#define MODEL_CAR "models/props_vehicles/cara_82hatchback.mdl"
#define MODEL_CAR2 "models/props_vehicles/cara_69sedan.mdl"
#define MODEL_CAR3 "models/props_vehicles/cara_84sedan.mdl"

bool g_bCloneInstalled, g_bTankConfig[ST_MAXTYPES + 1];

char g_sThrowAbility[ST_MAXTYPES + 1][9], g_sThrowAbility2[ST_MAXTYPES + 1][9], g_sThrowCarOptions[ST_MAXTYPES + 1][7], g_sThrowCarOptions2[ST_MAXTYPES + 1][7], g_sThrowInfectedOptions[ST_MAXTYPES + 1][15], g_sThrowInfectedOptions2[ST_MAXTYPES + 1][15], g_sThrowMessage[ST_MAXTYPES + 1][5], g_sThrowMessage2[ST_MAXTYPES + 1][5];

ConVar g_cvSTTankThrowForce;

float g_flThrowChance[ST_MAXTYPES + 1], g_flThrowChance2[ST_MAXTYPES + 1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (!bIsValidGame(false) && !bIsValidGame())
	{
		strcopy(error, err_max, "\"[ST++] Throw Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

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

	g_cvSTTankThrowForce = FindConVar("z_tank_throw_force");
}

public void OnMapStart()
{
	PrecacheModel(MODEL_CAR, true);
	PrecacheModel(MODEL_CAR2, true);
	PrecacheModel(MODEL_CAR3, true);
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

				kvSuperTanks.GetString("Throw Ability/Ability Enabled", g_sThrowAbility[iIndex], sizeof(g_sThrowAbility[]), "0");
				kvSuperTanks.GetString("Throw Ability/Ability Message", g_sThrowMessage[iIndex], sizeof(g_sThrowMessage[]), "0");
				kvSuperTanks.GetString("Throw Ability/Throw Car Options", g_sThrowCarOptions[iIndex], sizeof(g_sThrowCarOptions[]), "123");
				g_flThrowChance[iIndex] = kvSuperTanks.GetFloat("Throw Ability/Throw Chance", 33.3);
				g_flThrowChance[iIndex] = flClamp(g_flThrowChance[iIndex], 0.0, 100.0);
				kvSuperTanks.GetString("Throw Ability/Throw Infected Options", g_sThrowInfectedOptions[iIndex], sizeof(g_sThrowInfectedOptions[]), "1234567");
			}
			else
			{
				g_bTankConfig[iIndex] = true;

				kvSuperTanks.GetString("Throw Ability/Ability Enabled", g_sThrowAbility2[iIndex], sizeof(g_sThrowAbility2[]), g_sThrowAbility[iIndex]);
				kvSuperTanks.GetString("Throw Ability/Ability Message", g_sThrowMessage2[iIndex], sizeof(g_sThrowMessage2[]), g_sThrowMessage[iIndex]);
				kvSuperTanks.GetString("Throw Ability/Throw Car Options", g_sThrowCarOptions2[iIndex], sizeof(g_sThrowCarOptions2[]), g_sThrowCarOptions[iIndex]);
				g_flThrowChance2[iIndex] = kvSuperTanks.GetFloat("Throw Ability/Throw Chance", g_flThrowChance[iIndex]);
				g_flThrowChance2[iIndex] = flClamp(g_flThrowChance2[iIndex], 0.0, 100.0);
				kvSuperTanks.GetString("Throw Ability/Throw Infected Options", g_sThrowInfectedOptions2[iIndex], sizeof(g_sThrowInfectedOptions2[]), g_sThrowInfectedOptions[iIndex]);
			}

			kvSuperTanks.Rewind();
		}
	}

	delete kvSuperTanks;
}

public void ST_RockThrow(int tank, int rock)
{
	float flThrowChance = !g_bTankConfig[ST_TankType(tank)] ? g_flThrowChance[ST_TankType(tank)] : g_flThrowChance2[ST_TankType(tank)];
	if (GetRandomFloat(0.1, 100.0) <= flThrowChance && ST_TankAllowed(tank) && ST_CloneAllowed(tank, g_bCloneInstalled) && IsPlayerAlive(tank))
	{
		DataPack dpThrow;
		CreateDataTimer(0.1, tTimerThrow, dpThrow, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
		dpThrow.WriteCell(EntIndexToEntRef(rock));
		dpThrow.WriteCell(GetClientUserId(tank));
	}
}

public Action tTimerThrow(Handle timer, DataPack pack)
{
	pack.Reset();

	int iRock = EntRefToEntIndex(pack.ReadCell());
	if (iRock == INVALID_ENT_REFERENCE || !bIsValidEntity(iRock))
	{
		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell());
	char sThrowAbility[9];
	sThrowAbility = !g_bTankConfig[ST_TankType(iTank)] ? g_sThrowAbility[ST_TankType(iTank)] : g_sThrowAbility2[ST_TankType(iTank)];
	if (!ST_TankAllowed(iTank) || !IsPlayerAlive(iTank) || !ST_CloneAllowed(iTank, g_bCloneInstalled) || StrEqual(sThrowAbility, ""))
	{
		return Plugin_Stop;
	}

	float flVelocity[3];
	GetEntPropVector(iRock, Prop_Data, "m_vecVelocity", flVelocity);

	float flVector = GetVectorLength(flVelocity);
	if (flVector > 500.0)
	{
		char sAbilities = !g_bTankConfig[ST_TankType(iTank)] ? g_sThrowAbility[ST_TankType(iTank)][GetRandomInt(0, strlen(g_sThrowAbility[ST_TankType(iTank)]) - 1)] : g_sThrowAbility2[ST_TankType(iTank)][GetRandomInt(0, strlen(g_sThrowAbility2[ST_TankType(iTank)]) - 1)];
		switch (sAbilities)
		{
			case '1':
			{
				int iCar = CreateEntityByName("prop_physics");
				if (bIsValidEntity(iCar))
				{
					char sNumbers = !g_bTankConfig[ST_TankType(iTank)] ? g_sThrowCarOptions[ST_TankType(iTank)][GetRandomInt(0, strlen(g_sThrowCarOptions[ST_TankType(iTank)]) - 1)] : g_sThrowCarOptions2[ST_TankType(iTank)][GetRandomInt(0, strlen(g_sThrowCarOptions2[ST_TankType(iTank)]) - 1)];
					switch (sNumbers)
					{
						case '1': SetEntityModel(iCar, MODEL_CAR);
						case '2': SetEntityModel(iCar, MODEL_CAR2);
						case '3': SetEntityModel(iCar, MODEL_CAR3);
						default: SetEntityModel(iCar, MODEL_CAR);
					}

					int iRed = GetRandomInt(0, 255), iGreen = GetRandomInt(0, 255), iBlue = GetRandomInt(0, 255);
					SetEntityRenderColor(iCar, iRed, iGreen, iBlue, 255);

					float flPos[3];
					GetEntPropVector(iRock, Prop_Send, "m_vecOrigin", flPos);
					RemoveEntity(iRock);

					NormalizeVector(flVelocity, flVelocity);
					ScaleVector(flVelocity, g_cvSTTankThrowForce.FloatValue * 1.4);

					DispatchSpawn(iCar);
					TeleportEntity(iCar, flPos, NULL_VECTOR, flVelocity);

					CreateTimer(2.0, tTimerSetCarVelocity, EntIndexToEntRef(iCar), TIMER_FLAG_NO_MAPCHANGE);

					iCar = EntIndexToEntRef(iCar);
					vDeleteEntity(iCar, 10.0);

					char sThrowMessage[5];
					sThrowMessage = !g_bTankConfig[ST_TankType(iTank)] ? g_sThrowMessage[ST_TankType(iTank)] : g_sThrowMessage2[ST_TankType(iTank)];
					if (StrContains(sThrowMessage, "1") != -1)
					{
						char sTankName[33];
						ST_TankName(iTank, sTankName);
						ST_PrintToChatAll("%s %t", ST_TAG2, "Throw", sTankName);
					}
				}
			}
			case '2':
			{
				int iInfected = CreateFakeClient("Infected");
				if (iInfected > 0)
				{
					char sNumbers = !g_bTankConfig[ST_TankType(iTank)] ? g_sThrowInfectedOptions[ST_TankType(iTank)][GetRandomInt(0, strlen(g_sThrowInfectedOptions[ST_TankType(iTank)]) - 1)] : g_sThrowInfectedOptions2[ST_TankType(iTank)][GetRandomInt(0, strlen(g_sThrowInfectedOptions2[ST_TankType(iTank)]) - 1)];
					switch (sNumbers)
					{
						case '1': vSpawnInfected(iInfected, "smoker");
						case '2': vSpawnInfected(iInfected, "boomer");
						case '3': vSpawnInfected(iInfected, "hunter");
						case '4':
						{
							if (bIsValidGame())
							{
								vSpawnInfected(iInfected, "spitter");
							}
							else
							{
								vSpawnInfected(iInfected, "boomer");
							}
						}
						case '5':
						{
							if (bIsValidGame())
							{
								vSpawnInfected(iInfected, "jockey");
							}
							else
							{
								vSpawnInfected(iInfected, "hunter");
							}
						}
						case '6':
						{
							if (bIsValidGame())
							{
								vSpawnInfected(iInfected, "charger");
							}
							else
							{
								vSpawnInfected(iInfected, "smoker");
							}
						}
						case '7': vSpawnInfected(iInfected, "tank");
						default: vSpawnInfected(iInfected, "hunter");
					}

					float flPos[3];
					GetEntPropVector(iRock, Prop_Send, "m_vecOrigin", flPos);
					RemoveEntity(iRock);

					NormalizeVector(flVelocity, flVelocity);
					ScaleVector(flVelocity, g_cvSTTankThrowForce.FloatValue * 1.4);

					TeleportEntity(iInfected, flPos, NULL_VECTOR, flVelocity);

					char sThrowMessage[5];
					sThrowMessage = !g_bTankConfig[ST_TankType(iTank)] ? g_sThrowMessage[ST_TankType(iTank)] : g_sThrowMessage2[ST_TankType(iTank)];
					if (StrContains(sThrowMessage, "2") != -1)
					{
						char sTankName[33];
						ST_TankName(iTank, sTankName);
						ST_PrintToChatAll("%s %t", ST_TAG2, "Throw2", sTankName);
					}
				}
			}
			case '3':
			{
				float flPos[3];
				GetEntPropVector(iRock, Prop_Send, "m_vecOrigin", flPos);
				RemoveEntity(iRock);

				NormalizeVector(flVelocity, flVelocity);
				ScaleVector(flVelocity, g_cvSTTankThrowForce.FloatValue * 1.4);

				TeleportEntity(iTank, flPos, NULL_VECTOR, flVelocity);

				char sThrowMessage[5];
				sThrowMessage = !g_bTankConfig[ST_TankType(iTank)] ? g_sThrowMessage[ST_TankType(iTank)] : g_sThrowMessage2[ST_TankType(iTank)];
				if (StrContains(sThrowMessage, "3") != -1)
				{
					char sTankName[33];
					ST_TankName(iTank, sTankName);
					ST_PrintToChatAll("%s %t", ST_TAG2, "Throw3", sTankName);
				}
			}
			case '4':
			{
				int iWitch = CreateEntityByName("witch");
				if (bIsValidEntity(iWitch))
				{
					float flPos[3];
					GetEntPropVector(iRock, Prop_Send, "m_vecOrigin", flPos);
					RemoveEntity(iRock);

					NormalizeVector(flVelocity, flVelocity);
					ScaleVector(flVelocity, g_cvSTTankThrowForce.FloatValue * 1.4);

					DispatchSpawn(iWitch);
					ActivateEntity(iWitch);
					SetEntProp(iWitch, Prop_Send, "m_hOwnerEntity", iTank);

					TeleportEntity(iWitch, flPos, NULL_VECTOR, flVelocity);
				}

				char sThrowMessage[5];
				sThrowMessage = !g_bTankConfig[ST_TankType(iTank)] ? g_sThrowMessage[ST_TankType(iTank)] : g_sThrowMessage2[ST_TankType(iTank)];
				if (StrContains(sThrowMessage, "4") != -1)
				{
					char sTankName[33];
					ST_TankName(iTank, sTankName);
					ST_PrintToChatAll("%s %t", ST_TAG2, "Throw4", sTankName);
				}
			}
		}

		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public Action tTimerSetCarVelocity(Handle timer, int entity)
{
	int iCar = EntRefToEntIndex(entity);
	if (iCar == INVALID_ENT_REFERENCE || !bIsValidEntity(iCar))
	{
		return Plugin_Stop;
	}

	TeleportEntity(iCar, NULL_VECTOR, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));

	return Plugin_Continue;
}