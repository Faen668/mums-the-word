/***********************************************************************/
/** 	© 2015 CD PROJEKT S.A. All rights reserved.
/** 	THE WITCHER® is a trademark of CD PROJEKT S. A.
/** 	The Witcher game is based on the prose of Andrzej Sapkowski.
/***********************************************************************/




class W3LootPopupData extends CObject
{
	var targetContainer : W3Container;
}

class CR4LootPopup extends CR4PopupBase
{
	private const var KEY_LOOT_ITEM_LIST :string; default KEY_LOOT_ITEM_LIST = "LootItemList";
	
	private var _container 				: W3Container;
	private var m_fxSetWindowTitle 		: CScriptedFlashFunction;
	private var m_fxSetSelectionIndex	: CScriptedFlashFunction;
	private var m_fxSetWindowScale		: CScriptedFlashFunction;
	private var m_fxResizeBackground	:CScriptedFlashFunction;
	private var m_indexToSelect			: int; 							default m_indexToSelect = 0;
	private var safeLock 				: int;							default safeLock = -1;
	private var inputContextSet			: bool; 						default inputContextSet = false;
	
	event  OnConfigUI()
	{
		var lootPopupData : W3LootPopupData;
		var targetSize : float;
		
		super.OnConfigUI();
		
		setupFunctions();
		
		lootPopupData = (W3LootPopupData)GetPopupInitData();
		
		theGame.ForceUIAnalog(true);
		theGame.GetGuiManager().RequestMouseCursor(true);
		
		
		
		if (lootPopupData && lootPopupData.targetContainer && !theGame.IsDialogOrCutscenePlaying() && !theGame.GetGuiManager().IsAnyMenu())
		{
			theInput.StoreContext( 'EMPTY_CONTEXT' );
			inputContextSet = true;
			
			
			
			theSound.SoundEvent("gui_loot_popup_open");
			
			_container = lootPopupData.targetContainer;
			
			PopulateData();
			
			SignalLootingReactionEvent();
			
			if (StringToInt(theGame.GetInGameConfigWrapper().GetVarValue('Hud', 'HudSize'), 0) == 0)
			{
				targetSize = 0.85;
				if (theInput.LastUsedPCInput())
				{
					theGame.MoveMouseTo(0.4, 0.63);
				}
			}
			else
			{
				targetSize = 1;
				if (theInput.LastUsedPCInput())
				{
					theGame.MoveMouseTo(0.4, 0.58);
				}
			}
			
			m_fxSetWindowScale.InvokeSelfOneArg(FlashArgNumber(targetSize));
		}
		else
		{
			ClosePopup();
		}
	}
	
	private function setupFunctions():void
	{
		m_fxSetWindowTitle = m_flashModule.GetMemberFlashFunction( "SetWindowTitle" );
		m_fxSetSelectionIndex = m_flashModule.GetMemberFlashFunction( "SetSelectionIndex" );
		m_fxSetWindowScale = m_flashModule.GetMemberFlashFunction( "SetWindowScale" );
		m_fxResizeBackground = m_flashModule.GetMemberFlashFunction( "resizeBackground" );
		
	}
	
	event  OnClosingPopup()
	{
		theSound.SoundEvent("gui_loot_popup_close");
		super.OnClosingPopup();
		if (theInput.GetContext() == 'EMPTY_CONTEXT' && inputContextSet)
		{
			theInput.RestoreContext( 'EMPTY_CONTEXT', false );
		}
		
		theGame.GetGuiManager().RequestMouseCursor(false);
		theGame.ForceUIAnalog(false);

		SignalContainerClosedEvent();
		
		
		if(ShouldProcessTutorial('TutorialLootWindow'))
		{
			FactsAdd("tutorial_container_close", 1, 1 );	
		}
		if( _container )
		{
			_container.OnContainerClosed();
		}
	}
	
	public function UpdateInputContext():void
	{
		var currentContext : name;
		
		currentContext = theInput.GetContext();
		if (inputContextSet && currentContext != 'EMPTY_CONTEXT')
		{
			theInput.RestoreContext(currentContext, true);
			if (theInput.GetContext() == 'EMPTY_CONTEXT') 
			{
				theInput.RestoreContext('EMPTY_CONTEXT', true);
			}
			
			theInput.StoreContext(currentContext);
			
			ClosePopup();
		}
	}
	
	function PopulateData()
	{
		var i, j, length					: int;
		var l_lootItemsFlashArray			: CScriptedFlashArray;
		var l_lootItemsDataFlashObject 		: CScriptedFlashObject;
		var l_lootItemStatsFlashArray		: CScriptedFlashArray;
		var l_lootItemStatsDataFlashObject	: CScriptedFlashObject;
		
		var l_containerInv 					: CInventoryComponent = _container.GetInventory();
		var l_item 							: SItemUniqueId;
		var l_itemName						: string;
		var l_itemIconPath					: string;
		var l_itemQuantity					: int;
		var l_itemPrice						: float;
		var l_weight 						: float;
		var itemUIData						: SInventoryItemUIData;
		
		var l_name						    : name;
		var l_isBookRead					: bool;
		var l_isQuest	 					: bool;
		
		var l_allItems						: array<SItemUniqueId>;
		
		var l_primaryStatLabel   			: string;
		var l_primaryStatValue    			: float;
		
		var l_statsList						: CScriptedFlashArray;
		var l_itemStats 					: array<SAttributeTooltip>;
		var l_compareItem 					: SItemUniqueId;
		var l_compareItemStats				: array<SAttributeTooltip>;
		var l_itemTags 						: array<name>;
		var l_typeStr 						: string;
		var l_questTag						: string;
		var _value							: string;
		
		l_containerInv.GetAllItems( l_allItems );
		
		
		for(i=l_allItems.Size()-1; i>=0; i-=1)
			if( l_containerInv.ItemHasTag(l_allItems[i], theGame.params.TAG_DONT_SHOW ) && !l_containerInv.ItemHasTag(l_allItems[i], 'Lootable' ) )
				l_allItems.Erase(i);
		
		length	= l_allItems.Size();
		if(length > 4)
		{
			m_fxResizeBackground.InvokeSelfOneArg(FlashArgBool(true));
		}
		else
		{
			m_fxResizeBackground.InvokeSelfOneArg(FlashArgBool(false));
		}
	
		l_lootItemsFlashArray = m_flashValueStorage.CreateTempFlashArray();
		l_lootItemsFlashArray.SetLength( length );
		
		for	( i = 0 ; i < length; i+=1 )
		{
			l_item			= l_allItems[i];
			l_name			= l_containerInv.GetItemName(l_item);
			l_itemName 		= l_containerInv.GetItemLocalizedNameByUniqueID(l_item);
			
			l_itemName = GetLocStringByKeyExt(l_itemName);
			if ( l_itemName == "" )
			{
				l_itemName = " ";
			}

			if(l_containerInv.IsItemSingletonItem(l_item))
			{
				l_itemQuantity = thePlayer.inv.SingletonItemGetAmmo(l_item); 
			}
			else
			{
				l_itemQuantity = l_containerInv.GetItemQuantity( l_item );
			}
			
			
			l_itemIconPath	= l_containerInv.GetItemIconPathByUniqueID( l_item );
			
			if( l_containerInv.ItemHasTag(l_item, 'Quest') || l_containerInv.IsItemIngredient(l_item) || l_containerInv.IsItemAlchemyItem(l_item) ) 
			{
				l_weight = 0;
			}
			else
			{
				l_weight = l_containerInv.GetItemEncumbrance( l_item );
			}
			l_questTag = "";
			l_isQuest = false;
			if(l_containerInv.ItemHasTag(l_item, 'Quest'))
			{
				l_questTag = "Quest";
				l_isQuest = true;
			}
			
			if (l_containerInv.ItemHasTag(l_item, 'QuestEP1'))
			{
				l_questTag = "QuestEP1";
				l_isQuest = true;
			}
			
			if (l_containerInv.ItemHasTag(l_item, 'QuestEP2'))
			{
				l_questTag = "QuestEP2";
				l_isQuest = true;
			}
			
			

			
			l_lootItemsDataFlashObject = m_flashValueStorage.CreateTempFlashObject();
			l_isBookRead = l_containerInv.IsBookReadByName(l_name);
			
			l_lootItemsDataFlashObject.SetMemberFlashString ( "WeightValue", NoTrailZeros(l_weight));
			l_lootItemsDataFlashObject.SetMemberFlashString	( "label", l_itemName );
			l_lootItemsDataFlashObject.SetMemberFlashInt	( "quantity", l_itemQuantity );
			l_lootItemsDataFlashObject.SetMemberFlashNumber	( "PriceValue", l_itemPrice );
			l_lootItemsDataFlashObject.SetMemberFlashString ( "iconPath", l_itemIconPath );
			l_lootItemsDataFlashObject.SetMemberFlashInt	( "quality", l_containerInv.GetItemQuality( l_item ) );
			l_lootItemsDataFlashObject.SetMemberFlashBool	( "isRead", l_isBookRead );
			l_lootItemsDataFlashObject.SetMemberFlashBool   ( "isQuestItem", l_isQuest );
			l_lootItemsDataFlashObject.SetMemberFlashString ( "questTag", l_questTag );
			
			l_containerInv.GetItemTags(l_item,l_itemTags);
			GetWitcherPlayer().GetItemEquippedOnSlot(GetSlotForItem(l_containerInv.GetItemCategory(l_item),l_itemTags, true), l_compareItem);
			
			if( l_containerInv.GetItemName(l_item) != GetWitcherPlayer().GetInventory().GetItemName(l_compareItem) ) 
			{
				GetWitcherPlayer().GetInventory().GetItemStats(l_compareItem, l_compareItemStats);
			}
			l_statsList = m_flashValueStorage.CreateTempFlashArray();
			l_containerInv.GetItemStats(l_item, l_itemStats);
			CompareItemsStats(l_itemStats, l_compareItemStats, l_statsList);
			
			l_lootItemsDataFlashObject.SetMemberFlashArray("StatsList", l_statsList);
			
			if( l_containerInv.IsItemWeapon( l_item ) || l_containerInv.IsItemAnyArmor( l_item ) )
			{
				l_typeStr = GetItemRarityDescription(l_item, l_containerInv);
			}
			else
			{
				l_typeStr = "";
			}
		
			l_lootItemsDataFlashObject.SetMemberFlashString("itemType", l_typeStr );
			
			if(l_containerInv.HasItemDurability(l_item))
			{
				l_lootItemsDataFlashObject.SetMemberFlashString("DurabilityValue", NoTrailZeros(l_containerInv.GetItemDurability(l_item)/l_containerInv.GetItemMaxDurability(l_item) * 100));
			}
			else
			{
				l_lootItemsDataFlashObject.SetMemberFlashString("DurabilityValue", "");
			}
			l_containerInv.GetItemPrimaryStat(l_item, l_primaryStatLabel, l_primaryStatValue);
			
			l_lootItemsDataFlashObject.SetMemberFlashString("PrimaryStatLabel", l_primaryStatLabel);
			l_lootItemsDataFlashObject.SetMemberFlashNumber("PrimaryStatValue", l_primaryStatValue);	
			
			l_lootItemsFlashArray.SetElementFlashObject( i, l_lootItemsDataFlashObject );
		}
		
		m_flashValueStorage.SetFlashArray( KEY_LOOT_ITEM_LIST, l_lootItemsFlashArray );
		
		m_fxSetWindowTitle.InvokeSelfOneArg( FlashArgString( _container.GetDisplayName() ) );		
	}
	
	function CompareItemsStats(itemStats : array<SAttributeTooltip>, compareItemStats : array<SAttributeTooltip>, out compResult : CScriptedFlashArray)
	{
		var l_flashObject	: CScriptedFlashObject;
		var attributeVal 	: SAbilityAttributeValue;
		var strDifference 	: string;		
		var percentDiff 	: float;
		var nDifference 	: float;
		var i, j, price 	: int;
		
		strDifference = "none";
		for( i = 0; i < itemStats.Size(); i += 1 ) 
		{
			l_flashObject = m_flashValueStorage.CreateTempFlashObject();
			l_flashObject.SetMemberFlashString("name",itemStats[i].attributeName);
			l_flashObject.SetMemberFlashString("color",itemStats[i].attributeColor);
			
			
			for( j = 0; j < compareItemStats.Size(); j += 1 )
			{
				if( itemStats[j].attributeName == compareItemStats[i].attributeName )
				{
					nDifference = itemStats[j].value - compareItemStats[i].value;
					percentDiff = AbsF(nDifference/itemStats[j].value);
					
					
					if(nDifference > 0)
					{
						if(percentDiff < 0.25) 
							strDifference = "better";
						else if(percentDiff > 0.75) 
							strDifference = "wayBetter";
						else						
							strDifference = "reallyBetter";
					}
					
					else if(nDifference < 0)
					{
						if(percentDiff < 0.25) 
							strDifference = "worse";
						else if(percentDiff > 0.75) 
							strDifference = "wayWorse";
						else						
							strDifference = "reallyWorse";					
					}
					break;					
				}
			}
			l_flashObject.SetMemberFlashString("icon", strDifference);
			
			if( itemStats[i].percentageValue )
			{
				l_flashObject.SetMemberFlashString("value",NoTrailZeros(itemStats[i].value * 100 ) +" %");
			}
			else
			{
				if(itemStats[i].value < 0)
					l_flashObject.SetMemberFlashString("value",NoTrailZeros(itemStats[i].value));
				else
					l_flashObject.SetMemberFlashString("value","+" + NoTrailZeros(itemStats[i].value));				
			}
			compResult.PushBackFlashObject(l_flashObject);
		}	
	}
	
	function GetItemRarityDescription( item : SItemUniqueId, tooltipInv : CInventoryComponent ) : string
	{
		var itemQuality : int;
		
		itemQuality = tooltipInv.GetItemQuality(item);
		return GetItemRarityDescriptionFromInt(itemQuality);
	}
	
	event  OnPopupTakeAllItems( ) : void
	{
		GetWitcherPlayer().StartInvUpdateTransaction();
		SignalStealingReactionEvent();
		TakeAllAction();
		GetWitcherPlayer().FinishInvUpdateTransaction();
		
		OnCloseLootWindow();
	}
	
	event  OnPopupTakeItem( Id : int ) : void
	{
		var containerInv 		: CInventoryComponent;
		var playerInv 			: CInventoryComponent;
		var item 				: SItemUniqueId;
		var invalidatedItems 	: array< SItemUniqueId >;
		var itemName 			: name;
		var itemQuantity, i		: int;
		var category			: name;
		
		var l_allItems			: array<SItemUniqueId>;
		
		SignalStealingReactionEvent();
		
		m_indexToSelect = Id;
		
		containerInv 	= _container.GetInventory();
		playerInv 		= GetWitcherPlayer().inv;
		containerInv.GetAllItems( l_allItems );
		
		for( i = l_allItems.Size() - 1; i >= 0; i -= 1 )
		{
			if( ( containerInv.ItemHasTag(l_allItems[i],theGame.params.TAG_DONT_SHOW) || containerInv.ItemHasTag(l_allItems[i],'NoDrop') ) && !containerInv.ItemHasTag(l_allItems[i], 'Lootable' ) )
			{
				l_allItems.Erase(i);
			}
		}
		
		item 			= l_allItems[ Id ];
		itemName 		= containerInv.GetItemName(item);
		itemQuantity 	= containerInv.GetItemQuantity(item);
		if( containerInv.ItemHasTag(item, 'HerbGameplay') )
		{
			category	 	= 'herb';
		}
		else
		{
			category	 	= containerInv.GetItemCategory(item);
		}
		
		containerInv.NotifyItemLooted( item );
		containerInv.GiveItemTo( playerInv, item, itemQuantity, true, false, true );
		PlayItemEquipSound( category );
		
		containerInv.GetAllItems( l_allItems );
		for( i = l_allItems.Size() - 1; i >= 0; i -= 1 )
		{
			if( (containerInv.ItemHasTag(l_allItems[i],theGame.params.TAG_DONT_SHOW) || containerInv.ItemHasTag(l_allItems[i],'NoDrop') ) && !containerInv.ItemHasTag(l_allItems[i], 'Lootable' ) )
			{
				l_allItems.Erase(i);
			}
		}
		
		if( _container )
		{
			_container.InformClueStash();
		}
		
		if( l_allItems.Size() == 0)
		{
			OnCloseLootWindow();
			_container.Enable( false);
		}
		else
		{
			m_fxSetSelectionIndex.InvokeSelfOneArg( FlashArgInt( m_indexToSelect ) );
			PopulateData();
		}
	}
	
	event  OnCloseLootWindow()
	{
		ClosePopup();
	}
	
	
	function TakeAllAction() : void
	{
		_container.TakeAllItems();
	}
	
	protected function SignalLootingReactionEvent()
	{
		return; //modMumsTheWord
		if ( _container.disableStealing )
			return;
		if ( _container.HasQuestItem() )
			return;
		if ( (W3Herb)_container )
			return;
		if ( (W3ActorRemains)_container )
			return;
			
		theGame.CreateNoSaveLock("Stealing",safeLock,true);
		
		theGame.GetBehTreeReactionManager().CreateReactionEventIfPossible( thePlayer, 'LootingAction', -1, 10.0f, -1.f, -1, true); 
	}
	
	protected function SignalStealingReactionEvent()
	{
		return; //modMumsTheWord
		if ( _container.disableStealing || _container.HasQuestItem() || (W3Herb)_container || (W3ActorRemains)_container )
			return;
		
		theGame.GetBehTreeReactionManager().CreateReactionEventIfPossible( thePlayer, 'StealingAction', -1, 10.0f, -1.f, -1, true); 
	}
	
	protected function SignalContainerClosedEvent()
	{
		theGame.ReleaseNoSaveLock(safeLock);
		
		if ( _container.disableStealing || _container.HasQuestItem() || (W3Herb)_container || (W3ActorRemains)_container )
			return;
			
		theGame.GetBehTreeReactionManager().CreateReactionEventIfPossible( thePlayer, 'ContainerClosed', 10, 15.0f, -1.f, -1, true); 
	}
}

exec function CloseLootPopup()
{
	theGame.ClosePopup('LootPopup');
}