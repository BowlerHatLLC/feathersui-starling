/*
Feathers
Copyright 2012-2018 Bowler Hat LLC. All Rights Reserved.

This program is free software. You can redistribute and/or modify it in
accordance with the terms of the accompanying license agreement.
*/
package feathers.motion
{
	import starling.display.DisplayObject;
	import feathers.motion.effectClasses.IEffectContext;
	import feathers.motion.effectClasses.SequenceEffectContext;

	/**
	 * Combines multiple effects that play one after another in sequence. 
	 *
	 * @productversion Feathers 3.5.0
	 */
	public class Sequence
	{
		/**
		 * Creates an effect function that combines multiple effect functions
		 * that will play one after another, in sequence.
		 *
		 * @productversion Feathers 3.5.0
		 */
		public static function createSequenceEffect(effect1:Function, effect2:Function, ...rest:Array):Function
		{
			rest.unshift(effect2);
			rest.unshift(effect1);
			return function(target:DisplayObject):IEffectContext
			{
				return new SequenceEffectContext(target, rest);
			}
		}
	}
}