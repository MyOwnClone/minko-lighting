package aerys.minko.render.effect.lighting.offscreen
{
	import aerys.minko.render.RenderTarget;
	import aerys.minko.render.material.basic.BasicProperties;
	import aerys.minko.render.effect.lighting.LightingProperties;
	import aerys.minko.render.shader.SFloat;
	import aerys.minko.render.shader.Shader;
	import aerys.minko.render.shader.ShaderSettings;
	import aerys.minko.render.shader.part.DiffuseShaderPart;
	import aerys.minko.render.shader.part.animation.VertexAnimationShaderPart;
	import aerys.minko.render.shader.part.projection.IProjectionShaderPart;
	import aerys.minko.render.shader.part.projection.ParaboloidProjectionShaderPart;
	import aerys.minko.type.enum.Blending;
	
	import flash.geom.Rectangle;
	
	public class ParaboloidShadowMapShader extends Shader
	{
		private static const PROJECTION_RECTANGLE : Rectangle = new Rectangle(-1, 1, 2, -2);
		
		private var _vertexAnimationPart	: VertexAnimationShaderPart;
		private var _diffusePart			: DiffuseShaderPart;
		private var _projectorPart			: IProjectionShaderPart;
		
		private var _lightId				: uint;
		private var _priority				: Number;
		private var _renderTarget			: RenderTarget;
		
		private var _lightSpacePosition		: SFloat;
		
		public function ParaboloidShadowMapShader(lightId	: uint,
												  front		: Boolean,
												  priority	: Number,
												  target	: RenderTarget)
		{
			_lightId				= lightId;	
			_vertexAnimationPart	= new VertexAnimationShaderPart(this);
			_diffusePart			= new DiffuseShaderPart(this);
			_projectorPart			= new ParaboloidProjectionShaderPart(this, front);
		}
		
		override protected function initializeSettings(passConfig : ShaderSettings) : void
		{
			passConfig.blending		= Blending.NORMAL;
			passConfig.priority		= _priority;
			passConfig.renderTarget	= _renderTarget;
			passConfig.enabled		= meshBindings.getConstant(LightingProperties.CAST_SHADOWS, true);
		}
		
		override protected function getVertexPosition() : SFloat
		{
			var worldToLight		: SFloat = sceneBindings.getParameter('lightWorldToLight' + _lightId, 16);
			var position			: SFloat = _vertexAnimationPart.getAnimatedVertexPosition();
			var worldPosition		: SFloat = localToWorld(position);
			var lightPosition		: SFloat = multiply4x4(worldPosition, worldToLight);
			var clipspacePosition	: SFloat = _projectorPart.projectVector(
				lightPosition, PROJECTION_RECTANGLE, 0, 50
			);
			
			_lightSpacePosition = interpolate(lightPosition);
			
			return float4(clipspacePosition, 1);
		}
		
		override protected function getPixelColor() : SFloat
		{
			var clipspacePosition	: SFloat = _projectorPart.projectVector(
				_lightSpacePosition,
				PROJECTION_RECTANGLE,
				0,
				50
			);
			
			if (meshBindings.propertyExists(BasicProperties.ALPHA_THRESHOLD))
			{
				var diffuse			: SFloat	= _diffusePart.getDiffuse();
				var alphaThreshold 	: SFloat 	= meshBindings.getParameter('alphaThreshold', 1);
				
				kill(subtract(0.5, lessThan(diffuse.w, alphaThreshold)));
			}
			
			return float4(clipspacePosition.zzz, 1);
		}
	}
}
