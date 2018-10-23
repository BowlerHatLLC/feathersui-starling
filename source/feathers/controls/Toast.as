/*
Feathers
Copyright 2012-2018 Bowler Hat LLC. All Rights Reserved.

This program is free software. You can redistribute and/or modify it in
accordance with the terms of the accompanying license agreement.
*/
package feathers.controls
{
	import feathers.core.FeathersControl;
	import feathers.layout.HorizontalAlign;
	import feathers.layout.VerticalAlign;
	import feathers.core.PopUpManager;
	import feathers.skins.IStyleProvider;
	import feathers.core.ITextRenderer;
	import feathers.layout.VerticalLayout;
	import starling.events.Event;
	import starling.text.TextFormat;
	import feathers.text.FontStylesSet;
	import starling.display.DisplayObject;
	import feathers.core.IFeathersControl;
	import feathers.data.IListCollection;
	import feathers.events.FeathersEventType;
	import feathers.layout.HorizontalLayout;
	import flash.utils.getTimer;
	import feathers.motion.Fade;
	import feathers.motion.effectClasses.IEffectContext;

	/**
	 *
	 * @productversion Feathers 4.0.0
	 */
	public class Toast extends LayoutGroup
	{
		/**
		 * The default value added to the <code>styleNameList</code> of the
		 * message text renderer.
		 *
		 * @see feathers.core.FeathersControl#styleNameList
		 * @see ../../../help/text-renderers.html Introduction to Feathers text renderers
		 */
		public static const DEFAULT_CHILD_STYLE_NAME_MESSAGE:String = "feathers-toast-message";

		/**
		 * The default value added to the <code>styleNameList</code> of the
		 * actions butotn group.
		 *
		 * @see feathers.core.FeathersControl#styleNameList
		 */
		public static const DEFAULT_CHILD_STYLE_NAME_ACTIONS_GROUP:String = "feathers-toast-actions";

		/**
		 * @private
		 */
		protected static const INVALIDATION_FLAG_ACTIONS_FACTORY:String = "actionsFactory";

		/**
		 * The default <code>IStyleProvider</code> for all <code>Toast</code>
		 * components.
		 *
		 * @default null
		 * 
		 * @see feathers.core.FeathersControl#styleProvider
		 */
		public static var globalStyleProvider:IStyleProvider;

		/**
		 * @private
		 */
		private static var _maxVisibleToasts:int = 1;

		/**
		 * The maximum number of toasts that can be displayed simultaneously.
		 * Additional toasts will be queued up to display after the current
		 * toasts are removed.
		 */
		public static function get maxVisibleToasts():int
		{
			return _maxVisibleToasts;
		}

		/**
		 * @private
		 */
		public static function set maxVisibleToasts(value:int):void
		{
			if(_maxVisibleToasts == value)
			{
				return;
			}
			if(value <= 0)
			{
				throw new RangeError("maxVisibleToasts must be greater than 0.");
			}
			_maxVisibleToasts = value;
			while(_activeToasts.length < _maxVisibleToasts && _queue.length > 0)
			{
				showNextInQueue();
			}
		}

		/**
		 * @private
		 */
		private static var _queueMode:String = ToastQueueMode.CANCEL_TIMEOUT;

		/**
		 * Determines how timeouts are treated when toasts need to be queued up
		 * because there are already <code>maxVisibleToasts</code> visible.
		 * Either waits until the timeout is complete, or immediately closes an
		 * existing toast and shows the queued toast after the closing effect is
		 * done.
		 */
		public static function get queueMode():String
		{
			return _queueMode;
		}

		/**
		 * @private
		 */
		public static function set queueMode(value:String):void
		{
			_queueMode = value;
		}

		/**
		 * @private
		 */
		protected static var _activeToasts:Vector.<Toast> = new <Toast>[];

		/**
		 * @private
		 */
		protected static var _queue:Vector.<Toast> = new <Toast>[];

		/**
		 * @private
		 */
		protected static var _container:LayoutGroup = null;

		/**
		 * Shows a toast with custom content.
		 * 
		 * @see #showMessage()
		 * @see #showMessageWithActions()
		 */
		public static function showContent(content:DisplayObject, timeout:Number = 4):void
		{
			var toast:Toast = new Toast();
			toast.addChild(content);
			showToast(toast, timeout);
		}

		/**
		 * Shows a toast with a simple text message.
		 * 
		 * @see #showMessageWithActions()
		 * @see #showContent()
		 */
		public static function showMessage(message:String, timeout:Number = 4):void
		{
			var toast:Toast = new Toast();
			toast.message = message;
			showToast(toast, timeout);
		}

		/**
		 * Shows a toast with a text message and some action buttons.
		 * 
		 * @see #showMessage()
		 * @see #showContent()
		 */
		public static function showMessageWithActions(message:String, actions:IListCollection, timeout:Number = 4):void
		{
			var toast:Toast = new Toast();
			toast.message = message;
			toast.actions = actions;
			showToast(toast, timeout);
		}

		/**
		 * Shows a toast instance.
		 * 
		 * @see #showMessage()
		 * @see #showMessageWithActions()
		 * @see #showContent()
		 */
		public static function showToast(toast:Toast, timeout:Number):void
		{
			createContainer();
			toast.timeout = timeout;
			if(_activeToasts.length >= _maxVisibleToasts)
			{
				_queue[_queue.length] = toast;
				if(_queueMode == ToastQueueMode.CANCEL_TIMEOUT)
				{
					var toastCount:int = _activeToasts.length;
					for(var i:int = 0; i < toastCount; i++)
					{
						var activeToast:Toast = _activeToasts[i];
						if(activeToast.timeout < Number.POSITIVE_INFINITY)
						{
							activeToast.close(activeToast.disposeOnSelfClose);
							break;
						}
					}
				}
				return;
			}
			_activeToasts[_activeToasts.length] = toast;
			toast.addEventListener(Event.CLOSE, toast_closeHandler);
			Toast._container.addChild(toast);
		}

		/**
		 * @private
		 */
		protected static function showNextInQueue():void
		{
			if(_queue.length == 0)
			{
				return;
			}
			var toast:Toast = _queue.shift();
			showToast(toast, toast.timeout);
		}

		/**
		 * @private
		 */
		protected static function toast_closeHandler(event:Event):void
		{
			var toast:Toast = Toast(event.currentTarget);
			toast.removeEventListener(Event.CLOSE, toast_closeHandler);
			var index:int = _activeToasts.indexOf(toast);
			_activeToasts.removeAt(index);
			showNextInQueue();
		}

		/**
		 * @private
		 */
		protected static function createContainer():void
		{
			if(Toast._container)
			{
				return;
			}
			Toast._container = new LayoutGroup();
			Toast._container.addEventListener(Event.REMOVED_FROM_STAGE, function():void
			{
				Toast._container = null;
			})
			Toast._container.autoSizeMode = AutoSizeMode.STAGE;
			var layout:VerticalLayout = new VerticalLayout();
			layout.horizontalAlign = HorizontalAlign.LEFT;
			layout.verticalAlign = VerticalAlign.BOTTOM;
			layout.padding = 20;
			layout.gap = 8;
			Toast._container.layout = layout;
			PopUpManager.addPopUp(Toast._container, false, false);
		}

		/**
		 * The default factory that creates the action button group. To use a
		 * different factory, you need to set <code>actionsGroupFactory</code>
		 * to a <code>Function</code> instance.
		 */
		public static function defaultActionsGroupFactory():ButtonGroup
		{
			return new ButtonGroup();
		}

		/**
		 * Constructor.
		 */
		public function Toast()
		{
			super();
			this._addedEffect = Fade.createFadeInEffect();
			if(this._fontStylesSet === null)
			{
				this._fontStylesSet = new FontStylesSet();
				this._fontStylesSet.addEventListener(Event.CHANGE, fontStyles_changeHandler);
			}
			this.addEventListener(Event.ADDED_TO_STAGE, toast_addedToStageHandler);
		}

		/**
		 * The value added to the <code>styleNameList</code> of the toast's
		 * message text renderer. This variable is <code>protected</code> so
		 * that sub-classes can customize the message style name in their
		 * constructors instead of using the default style name defined by
		 * <code>DEFAULT_CHILD_STYLE_NAME_MESSAGE</code>.
		 *
		 * @see feathers.core.FeathersControl#styleNameList
		 */
		protected var messageStyleName:String = DEFAULT_CHILD_STYLE_NAME_MESSAGE;

		/**
		 * The value added to the <code>styleNameList</code> of the toast's
		 * actions button group. This variable is <code>protected</code> so
		 * that sub-classes can customize the actions style name in their
		 * constructors instead of using the default style name defined by
		 * <code>DEFAULT_CHILD_STYLE_NAME_ACTIONS_GROUP</code>.
		 *
		 * @see feathers.core.FeathersControl#styleNameList
		 */
		protected var actionsGroupStyleName:String = DEFAULT_CHILD_STYLE_NAME_ACTIONS_GROUP;

		/**
		 * The message text renderer sub-component.
		 *
		 * <p>For internal use in subclasses.</p>
		 */
		protected var messageTextRenderer:ITextRenderer = null;

		/**
		 * The actions button group sub-component.
		 *
		 * <p>For internal use in subclasses.</p>
		 */
		protected var actionsGroup:ButtonGroup = null;

		/**
		 * @private
		 */
		override protected function get defaultStyleProvider():IStyleProvider
		{
			return Toast.globalStyleProvider;
		}

		/**
		 * @private
		 */
		protected var _message:String = null;

		/**
		 * The toast's main text content.
		 */
		public function get message():String
		{
			return this._message;
		}

		/**
		 * @private
		 */
		public function set message(value:String):void
		{
			if(this._message == value)
			{
				return;
			}
			this._message = value;
			this.invalidate(INVALIDATION_FLAG_DATA);
		}

		/**
		 * @private
		 */
		protected var _actions:IListCollection = null;

		/**
		 * The data provider of the toast's <code>ButtonGroup</code>.
		 */
		public function get actions():IListCollection
		{
			return this._actions;
		}

		/**
		 * @private
		 */
		public function set actions(value:IListCollection):void
		{
			if(this._actions == value)
			{
				return;
			}
			this._actions = value;
			this.invalidate(INVALIDATION_FLAG_DATA);
		}

		/**
		 * @private
		 */
		protected var _startTime:int = -1;

		/**
		 * @private
		 */
		protected var _timeout:Number = Number.POSITIVE_INFINITY;

		/**
		 * The time, in seconds, when the toast will automatically close. Set
		 * to <code>Number.POSITIVE_INFINITY</code> to require the toast to be
		 * closed manually.
		 * 
		 * @default Number.POSITIVE_INFINITY
		 */
		public function get timeout():Number
		{
			return this._timeout;
		}

		/**
		 * @private
		 */
		public function set timeout(value:Number):void
		{
			if(this._timeout == value)
			{
				return;
			}
			this._timeout = value;
			if(this.stage)
			{
				this.startTimeout();
			}
		}

		/**
		 * @private
		 */
		protected var _closeEffectContext:IEffectContext = null;

		/**
		 * @private
		 */
		protected var _closeEffect:Function = Fade.createFadeOutEffect();

		/**
		 * 
		 */
		public function get closeEffect():Function
		{
			return this._closeEffect;
		}

		/**
		 * @private
		 */
		public function set closeEffect(value:Function):void
		{
			if(this._closeEffect == value)
			{
				return;
			}
			this._closeEffect = value;
		}

		/**
		 * @private
		 */
		protected var _fontStylesSet:FontStylesSet = null;

		/**
		 * @private
		 */
		public function get fontStyles():TextFormat
		{
			return this._fontStylesSet.format;
		}

		/**
		 * @private
		 */
		public function set fontStyles(value:TextFormat):void
		{
			if(this.processStyleRestriction(arguments.callee))
			{
				return;
			}
			var savedCallee:Function = arguments.callee;
			function changeHandler(event:Event):void
			{
				processStyleRestriction(savedCallee);
			}
			if(value !== null)
			{
				value.removeEventListener(Event.CHANGE, changeHandler);
			}
			this._fontStylesSet.format = value;
			if(value !== null)
			{
				value.addEventListener(Event.CHANGE, changeHandler);
			}
		}

		/**
		 * @private
		 */
		public function get disabledFontStyles():TextFormat
		{
			return this._fontStylesSet.disabledFormat;
		}

		/**
		 * @private
		 */
		public function set disabledFontStyles(value:TextFormat):void
		{
			if(this.processStyleRestriction(arguments.callee))
			{
				return;
			}
			var savedCallee:Function = arguments.callee;
			function changeHandler(event:Event):void
			{
				processStyleRestriction(savedCallee);
			}
			if(value !== null)
			{
				value.removeEventListener(Event.CHANGE, changeHandler);
			}
			this._fontStylesSet.disabledFormat = value;
			if(value !== null)
			{
				value.addEventListener(Event.CHANGE, changeHandler);
			}
		}

		/**
		 * @private
		 */
		protected var _messageFactory:Function = null;

		/**
		 * A function used to instantiate the toast's message text renderer
		 * sub-component. By default, the toast will use the global text
		 * renderer factory, <code>FeathersControl.defaultTextRendererFactory()</code>,
		 * to create the message text renderer. The message text renderer must
		 * be an instance of <code>ITextRenderer</code>. This factory can be
		 * used to change properties on the message text renderer when it is
		 * first created. For instance, if you are skinning Feathers components
		 * without a theme, you might use this factory to style the message text
		 * renderer.
		 *
		 * <p>If you are not using a theme, the message factory can be used to
		 * provide skin the message text renderer with appropriate text styles.</p>
		 *
		 * <p>The factory should have the following function signature:</p>
		 * <pre>function():ITextRenderer</pre>
		 *
		 * <p>In the following example, a custom message factory is passed to
		 * the toast:</p>
		 *
		 * <listing version="3.0">
		 * toast.messageFactory = function():ITextRenderer
		 * {
		 *     var messageRenderer:TextFieldTextRenderer = new TextFieldTextRenderer();
		 *     messageRenderer.textFormat = new TextFormat( "_sans", 12, 0xff0000 );
		 *     return messageRenderer;
		 * }</listing>
		 *
		 * @default null
		 *
		 * @see #message
		 * @see feathers.core.ITextRenderer
		 * @see feathers.core.FeathersControl#defaultTextRendererFactory
		 */
		public function get messageFactory():Function
		{
			return this._messageFactory;
		}

		/**
		 * @private
		 */
		public function set messageFactory(value:Function):void
		{
			if(this._messageFactory == value)
			{
				return;
			}
			this._messageFactory = value;
			this.invalidate(INVALIDATION_FLAG_TEXT_RENDERER);
		}

		/**
		 * @private
		 */
		protected var _customMessageStyleName:String;

		/**
		 * @private
		 */
		public function get customMessageStyleName():String
		{
			return this._customMessageStyleName;
		}

		/**
		 * @private
		 */
		public function set customMessageStyleName(value:String):void
		{
			if(this.processStyleRestriction(arguments.callee))
			{
				return;
			}
			if(this._customMessageStyleName === value)
			{
				return;
			}
			this._customMessageStyleName = value;
			this.invalidate(INVALIDATION_FLAG_TEXT_RENDERER);
		}

		/**
		 * @private
		 */
		protected var _actionsGroupFactory:Function = null;

		/**
		 * A function used to generate the toast's button group sub-component.
		 * The button group must be an instance of <code>ButtonGroup</code>.
		 * This factory can be used to change properties on the button group
		 * when it is first created. For instance, if you are skinning Feathers
		 * components without a theme, you might use this factory to set skins
		 * and other styles on the button group.
		 *
		 * <p>The function should have the following signature:</p>
		 * <pre>function():ButtonGroup</pre>
		 *
		 * <p>In the following example, a custom button group factory is
		 * provided to the toast:</p>
		 *
		 * <listing version="3.0">
		 * toast.actionsGroupFactory = function():ButtonGroup
		 * {
		 *     return new ButtonGroup();
		 * };</listing>
		 *
		 * @default null
		 *
		 * @see feathers.controls.ButtonGroup
		 */
		public function get actionsGroupFactory():Function
		{
			return this._actionsGroupFactory;
		}

		/**
		 * @private
		 */
		public function set actionsGroupFactory(value:Function):void
		{
			if(this._actionsGroupFactory == value)
			{
				return;
			}
			this._actionsGroupFactory = value;
			this.invalidate(INVALIDATION_FLAG_ACTIONS_FACTORY);
		}

		/**
		 * @private
		 */
		protected var _customActionsGroupStyleName:String = null;

		/**
		 * @private
		 */
		public function get customActionsGroupStyleName():String
		{
			return this._customActionsGroupStyleName;
		}

		/**
		 * @private
		 */
		public function set customActionsGroupStyleName(value:String):void
		{
			if(this.processStyleRestriction(arguments.callee))
			{
				return;
			}
			if(this._customActionsGroupStyleName === value)
			{
				return;
			}
			this._customActionsGroupStyleName = value;
			this.invalidate(INVALIDATION_FLAG_ACTIONS_FACTORY);
		}

		/**
		 * @private
		 */
		protected var _disposeFromCloseCall:Boolean = false;

		/**
		 * @private
		 */
		protected var _disposeOnSelfClose:Boolean = true;

		/**
		 * Determines if the toast will be disposed when <code>close()</code>
		 * is called internally. Close may be called internally in a variety of
		 * cases, depending on values such as <code>timeout</code> and
		 * <code>actions</code>. If set to <code>false</code>, you may reuse the
		 * toast later by passing it to <code>Toast.showToast()</code>.
		 *
		 * <p>In the following example, the toast will not be disposed when it
		 * closes itself:</p>
		 *
		 * <listing version="3.0">
		 * toast.disposeOnSelfClose = false;</listing>
		 * 
		 * @default true
		 *
		 * @see #close()
		 */
		public function get disposeOnSelfClose():Boolean
		{
			return this._disposeOnSelfClose;
		}

		/**
		 * @private
		 */
		public function set disposeOnSelfClose(value:Boolean):void
		{
			this._disposeOnSelfClose = value;
		}

		/**
		 * @private
		 */
		override public function dispose():void
		{
			if(this._fontStylesSet !== null)
			{
				this._fontStylesSet.dispose();
				this._fontStylesSet = null;
			}
			super.dispose();
		}

		/**
		 * @inheritDoc
		 */
		public function close(dispose:Boolean = true):void
		{
			if(!this.parent)
			{
				return;
			}
			this._disposeFromCloseCall = dispose;
			this.removeEventListener(Event.ENTER_FRAME, this.toast_timeout_enterFrameHandler);
			if(this._closeEffect)
			{
				this._closeEffectContext = IEffectContext(this._closeEffect(this));
				this._closeEffectContext.addEventListener(Event.COMPLETE, closeEffectContext_completeHandler);
				this._closeEffectContext.play();
			}
			else
			{
				this.completeClose();
			}
		}

		/**
		 * @private
		 */
		override protected function initialize():void
		{
			if(this._layout === null)
			{
				var layout:HorizontalLayout = new HorizontalLayout();
				layout.horizontalAlign = HorizontalAlign.CENTER;
				this.ignoreNextStyleRestriction();
				this.layout = layout;
			}
			super.initialize();
		}

		/**
		 * @private
		 */
		override protected function draw():void
		{
			var dataInvalid:Boolean = this.isInvalid(INVALIDATION_FLAG_DATA);
			var stylesInvalid:Boolean = this.isInvalid(INVALIDATION_FLAG_STYLES);
			var stateInvalid:Boolean = this.isInvalid(INVALIDATION_FLAG_STATE);
			var textRendererInvalid:Boolean = this.isInvalid(INVALIDATION_FLAG_TEXT_RENDERER);
			var actionsInvalid:Boolean = this.isInvalid(INVALIDATION_FLAG_ACTIONS_FACTORY);

			if(textRendererInvalid)
			{
				this.createMessage();
			}

			if(actionsInvalid)
			{
				this.createActions();
			}

			if(textRendererInvalid || dataInvalid)
			{
				if(this.messageTextRenderer)
				{
					this.messageTextRenderer.text = this._message;
				}
			}

			if(textRendererInvalid || stylesInvalid)
			{
				this.refreshMessageStyles();
			}

			if(actionsInvalid || dataInvalid)
			{
				if(this.actionsGroup)
				{
					this.actionsGroup.dataProvider = this._actions;
				}
			}

			super.draw();
		}

		/**
		 * Creates and adds the <code>messageTextRenderer</code> sub-component and
		 * removes the old instance, if one exists.
		 *
		 * <p>Meant for internal use, and subclasses may override this function
		 * with a custom implementation.</p>
		 *
		 * @see #message
		 * @see #messageTextRenderer
		 * @see #messageFactory
		 */
		protected function createMessage():void
		{
			if(this.messageTextRenderer)
			{
				this.removeChild(DisplayObject(this.messageTextRenderer), true);
				this.messageTextRenderer = null;
			}

			if(this._message === null)
			{
				return;
			}

			var factory:Function = this._messageFactory != null ? this._messageFactory : FeathersControl.defaultTextRendererFactory;
			this.messageTextRenderer = ITextRenderer(factory());
			this.messageTextRenderer.wordWrap = true;
			var messageStyleName:String = this._customMessageStyleName != null ? this._customMessageStyleName : this.messageStyleName;
			var uiTextRenderer:IFeathersControl = IFeathersControl(this.messageTextRenderer);
			uiTextRenderer.styleNameList.add(messageStyleName);
			uiTextRenderer.touchable = false;
			this.addChild(DisplayObject(this.messageTextRenderer));
		}

		/**
		 * @private
		 */
		protected function refreshMessageStyles():void
		{
			this.messageTextRenderer.fontStyles = this._fontStylesSet;
		}

		/**
		 * Creates and adds the <code>buttonGroupFooter</code> sub-component and
		 * removes the old instance, if one exists.
		 *
		 * <p>Meant for internal use, and subclasses may override this function
		 * with a custom implementation.</p>
		 *
		 * @see #buttonGroupFooter
		 * @see #buttonGroupFactory
		 * @see #style:customButtonGroupStyleName
		 */
		protected function createActions():void
		{
			if(this.actionsGroup)
			{
				this.actionsGroup.removeEventListener(Event.TRIGGERED, actionsGroup_triggeredHandler);
				this.removeChild(this.actionsGroup, true);
				this.actionsGroup = null;
			}

			if(this._actions === null)
			{
				return;
			}
			var factory:Function = this._actionsGroupFactory !== null ? this._actionsGroupFactory : defaultActionsGroupFactory;
			if(factory === null)
			{
				return;
			}
			var actionsGroupStyleName:String = this._customActionsGroupStyleName != null ? this._customActionsGroupStyleName : this.actionsGroupStyleName;
			this.actionsGroup = ButtonGroup(factory());
			this.actionsGroup.styleNameList.add(actionsGroupStyleName);
			this.actionsGroup.addEventListener(Event.TRIGGERED, actionsGroup_triggeredHandler);
			this.addChild(this.actionsGroup);
		}

		/**
		 * @private
		 */
		protected function startTimeout():void
		{
			if(this._timeout == Number.POSITIVE_INFINITY)
			{
				this.removeEventListener(Event.ENTER_FRAME, this.toast_timeout_enterFrameHandler);
				return;
			}
			this._startTime = getTimer();
			this.addEventListener(Event.ENTER_FRAME, this.toast_timeout_enterFrameHandler);
		}

		/**
		 * @private
		 */
		protected function completeClose():void
		{
			this.dispatchEventWith(Event.CLOSE);
			this.removeFromParent(this._disposeFromCloseCall);
		}

		/**
		 * @private
		 */
		protected function toast_addedToStageHandler(event:Event):void
		{
			this.startTimeout();
		}

		/**
		 * @private
		 */
		protected function toast_timeout_enterFrameHandler(event:Event):void
		{
			var totalTime:int = (getTimer() - this._startTime) / 1000;
			if(totalTime > this._timeout)
			{
				this.close(this._disposeOnSelfClose);
			}
		}

		/**
		 * @private
		 */
		protected function fontStyles_changeHandler(event:Event):void
		{
			this.invalidate(INVALIDATION_FLAG_STYLES);
		}

		/**
		 * @private
		 */
		protected function actionsGroup_triggeredHandler(event:Event, data:Object):void
		{
			this.dispatchEventWith(Event.TRIGGERED, false, data);
			this.close(this._disposeOnSelfClose);
		}

		/**
		 * @private
		 */
		protected function closeEffectContext_completeHandler(event:Event):void
		{
			this.completeClose();
		}
	}
}