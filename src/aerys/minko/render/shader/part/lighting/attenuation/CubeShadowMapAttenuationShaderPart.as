package aerys.minko.render.shader.part.lighting.attenuation
{
	import aerys.minko.render.effect.lighting.LightingProperties;
	import aerys.minko.render.shader.SFloat;
	import aerys.minko.render.shader.Shader;
	import aerys.minko.render.shader.compiler.register.Components;
	import aerys.minko.render.shader.part.lighting.LightAwareShaderPart;
	import aerys.minko.type.enum.SamplerDimension;
	import aerys.minko.type.enum.SamplerFiltering;
	import aerys.minko.type.enum.SamplerMipMapping;
	import aerys.minko.type.enum.SamplerWrapping;
	
	public class CubeShadowMapAttenuationShaderPart extends LightAwareShaderPart implements IAttenuationShaderPart
	{
		private static const DEFAULT_BIAS : Number = 1 / 10000;
		
		public function CubeShadowMapAttenuationShaderPart(main : Shader)
		{
			super(main);
		}
		
		public function getAttenuation(lightId : uint) : SFloat
		{
			// retrieve shadow bias
			var shadowBias : SFloat;
			if (meshBindings.propertyExists(LightingProperties.SHADOW_BIAS))
				shadowBias = meshBindings.getParameter(LightingProperties.SHADOW_BIAS, 1);
			else if (sceneBindings.propertyExists(LightingProperties.SHADOW_BIAS))
				shadowBias = sceneBindings.getParameter(LightingProperties.SHADOW_BIAS, 1);
			else
				shadowBias = float(DEFAULT_BIAS);
			
			// retrieve depthmap, transformation matrix, zNear and zFar
			var worldToLight		: SFloat = getLightParameter(lightId, 'worldToLocal', 16);
			var zNear				: SFloat = getLightParameter(lightId, 'zNear', 1);
			var zFar				: SFloat = getLightParameter(lightId, 'zFar', 1);
			var cubeDepthMap		: SFloat = getLightTextureParameter(lightId, 'shadowMapCube', 
																		SamplerFiltering.NEAREST,
																		SamplerMipMapping.DISABLE, 
																		SamplerWrapping.CLAMP, 
																		SamplerDimension.CUBE);
			
			// retrieve precompute depth
			var positionFromLight	: SFloat = interpolate(multiply4x4(vsWorldPosition, worldToLight));
			var precomputedDepth	: SFloat = unpack(sampleTexture(cubeDepthMap, positionFromLight));
			
			// retrieve real depth
			var currentDepth		: SFloat = divide(subtract(length(positionFromLight.xyz), zNear), subtract(zFar, zNear));
			currentDepth = min(subtract(1, shadowBias), currentDepth);
			
			return lessEqual(currentDepth, add(shadowBias, precomputedDepth));
		}
	}
}
