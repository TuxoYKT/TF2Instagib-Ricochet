#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <instagib>
#include <tf2items>

ConVar cvBounceProjectile;

static bool IsRicochet;

static int numBounces[2048];

public void OnPluginStart()
{
	cvBounceProjectile = CreateConVar("instagib_ricochet_maxbounces",  "8", "How many times the projectile should bounce from walls?", _, true, 1.0)
}

public void IG_OnMapConfigLoad()
{
	InstagibRound round;
	
	// Fills the round array with default and config values
	IG_InitializeSpecialRound(round, "Ricochet", "Railguns now shoot ricocheting projectiles!");

	// Replace revolver to syringegun
	round.MainWeapon = CustomRoundRicochet_MainWeapon();

	round.OnStart = CustomRoundRicochet_OnStart;
	round.OnEnd = CustomRoundRicochet_OnEnd;
	
	// Add the round to the list of Special Rounds. It can't be edited or removed after this.gcv
	IG_SubmitSpecialRound(round);
} 

static Handle CustomRoundRicochet_MainWeapon()
{
	Handle hndl = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);

	TF2Items_SetClassname(hndl, "tf_weapon_shotgun_building_rescue");
	TF2Items_SetItemIndex(hndl, 527); //997
	TF2Items_SetLevel(hndl, 1);
	TF2Items_SetQuality(hndl, 4);
	TF2Items_SetNumAttributes(hndl, 8);

	TF2Items_SetAttribute(hndl, 0, 5, 2.0);     // slower firing speed
	TF2Items_SetAttribute(hndl, 1, 303, -1.0);  // no reloads
	TF2Items_SetAttribute(hndl, 2, 2, 10.0);	// +900% damage bonus
	TF2Items_SetAttribute(hndl, 3, 106, 0.0);   // +100% more accurate
	TF2Items_SetAttribute(hndl, 4, 51, 1.0);	// Crits on headshot
	TF2Items_SetAttribute(hndl, 5, 305, -1.0);  // Fires tracer rounds
	TF2Items_SetAttribute(hndl, 6, 851, 2.0);   // i am speed

	TF2Items_SetAttribute(hndl, 7, 2025, 1.0);  // killstreak

	return hndl;
}

void CustomRoundRicochet_OnStart()
{
	IsRicochet = true;
}

void CustomRoundRicochet_OnEnd()
{
	IsRicochet = false;
}

public void OnEntityCreated(int iEntity, const char[] strClassname)
{
	if(IsRicochet && StrEqual(strClassname, "tf_projectile_arrow"))
	{
		numBounces[iEntity] = 0;
		SDKHook(iEntity, SDKHook_StartTouch, Hook_OnStartTouch);
	}
}

public Action Hook_OnStartTouch(int iEntity, int iOther)
{
	if (iOther > 0 && iOther <= MaxClients)
		return Plugin_Continue;

	if (numBounces[iEntity] >= cvBounceProjectile.IntValue)
		return Plugin_Continue;

	SDKHook(iEntity, SDKHook_Touch, Hook_OnTouch);
	return Plugin_Handled;
}

public Action Hook_OnTouch(int iEntity)
{
	float vecOrigin[3], vecAngles[3], vecVelocity[3];
	GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", vecOrigin);
	GetEntPropVector(iEntity, Prop_Data, "m_angRotation", vecAngles);
	GetEntPropVector(iEntity, Prop_Data, "m_vecAbsVelocity", vecVelocity);

	Handle Trace = TR_TraceRayFilterEx(vecOrigin, vecAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilter_IgnoreEntity, iEntity);

	float vecNormal[3];
	TR_GetPlaneNormal(Trace, vecNormal);
	Trace.Close();
	
	float dotProduct = GetVectorDotProduct(vecNormal, vecVelocity);
	
	ScaleVector(vecNormal, dotProduct);
	ScaleVector(vecNormal, 2.0);
	
	float vecBounceVec[3];
	SubtractVectors(vecVelocity, vecNormal, vecBounceVec);
	
	float vecNewAngles[3];
	GetVectorAngles(vecBounceVec, vecNewAngles);
	
	TeleportEntity(iEntity, NULL_VECTOR, vecNewAngles, vecBounceVec);

	numBounces[iEntity]++;

	SDKUnhook(iEntity, SDKHook_Touch, Hook_OnTouch);
	return Plugin_Handled;
}

public bool TraceEntityFilter_IgnoreEntity(int entity, int mask, any data)
{
	return (entity != data);
}

public Action TF2_CalcIsAttackCritical(int client, int weapon, char[] weaponname, bool &result)
{
	if (IsRicochet && StrEqual(weaponname, "tf_weapon_shotgun_building_rescue") && IsValidEntity(weapon)) 
		SetEntProp(weapon, Prop_Data, "m_iClip1", 32);
    
	return Plugin_Continue;
}