class_name RewardProvider
extends RefCounted

# Implement with a native SDK and grant access only after its verified reward callback.
func rewarded_available() -> bool:
	return false

func product_available(_product_id: String) -> bool:
	return false
