#include "tiling_render_policy_st.hpp"
#include "window_handle.hpp"
#include "queued_renderer.hpp"
#include "tile_renderer.hpp"
#include "coverage_generator.hpp"

#include "platform/platform.hpp"

#include "graphics/opengl/opengl.hpp"
#include "graphics/render_context.hpp"


using namespace graphics;

TilingRenderPolicyST::TilingRenderPolicyST(Params const & p)
  : BasicTilingRenderPolicy(p,
                            true)
{
  ResourceManager::Params rmp = p.m_rmParams;

  rmp.checkDeviceCaps();
  bool useNpot = rmp.canUseNPOTextures();

  rmp.m_textureParams[ELargeTexture]        = GetTextureParam(GetLargeTextureSize(useNpot), 1, rmp.m_texFormat, ELargeTexture);
  rmp.m_textureParams[EMediumTexture]       = GetTextureParam(GetMediumTextureSize(useNpot), 10, rmp.m_texFormat, EMediumTexture);
  rmp.m_textureParams[ERenderTargetTexture] = GetTextureParam(TileSize(), 1, rmp.m_texRtFormat, ERenderTargetTexture);
  rmp.m_textureParams[ESmallTexture]        = GetTextureParam(GetSmallTextureSize(useNpot), 2, rmp.m_texFormat, ESmallTexture);

  rmp.m_storageParams[ELargeStorage]        = GetStorageParam(6000, 9000, 10, ELargeStorage);
  rmp.m_storageParams[EMediumStorage]       = GetStorageParam(6000, 9000, 1, EMediumStorage);
  rmp.m_storageParams[ESmallStorage]        = GetStorageParam(2000, 4000, 5, ESmallStorage);
  rmp.m_storageParams[ETinyStorage]         = GetStorageParam(100, 200, 5, ETinyStorage);

  rmp.m_glyphCacheParams = GetResourceGlyphCacheParams(Density());

  rmp.m_threadSlotsCount = m_cpuCoresCount + 2;
  rmp.m_renderThreadsCount = m_cpuCoresCount;

  rmp.m_useSingleThreadedOGL = true;

  m_resourceManager.reset(new graphics::ResourceManager(rmp, SkinName(), Density()));

  m_primaryRC->setResourceManager(m_resourceManager);
  m_primaryRC->startThreadDrawing(m_resourceManager->guiThreadSlot());

  Platform::FilesList fonts;
  GetPlatform().GetFontNames(fonts);
  m_resourceManager->addFonts(fonts);

  m_drawer.reset(CreateDrawer(p.m_useDefaultFB, p.m_primaryRC, ESmallStorage, ESmallTexture));
  InitCacheScreen();
  InitWindowsHandle(p.m_videoTimer, m_primaryRC);
}

TilingRenderPolicyST::~TilingRenderPolicyST()
{
  LOG(LDEBUG, ("cancelling ResourceManager"));
  m_resourceManager->cancel();

  LOG(LDEBUG, ("deleting TilingRenderPolicyST"));

  m_QueuedRenderer->PrepareQueueCancellation(m_cpuCoresCount);
  /// now we should process all commands to collect them into queues
  m_CoverageGenerator->Shutdown();
  m_QueuedRenderer->CancelQueuedCommands(m_cpuCoresCount);

  /// firstly stop all rendering commands in progress and collect all commands into queues

  for (unsigned i = 0; i < m_cpuCoresCount; ++i)
    m_QueuedRenderer->PrepareQueueCancellation(i);

  m_TileRenderer->Shutdown();
  /// now we should cancel all collected commands

  for (unsigned i = 0; i < m_cpuCoresCount; ++i)
    m_QueuedRenderer->CancelQueuedCommands(i);

  LOG(LDEBUG, ("reseting coverageGenerator"));
  m_CoverageGenerator.reset();
  LOG(LDEBUG, ("reseting tileRenderer"));
  m_TileRenderer.reset();
  LOG(LDEBUG, ("done reseting tileRenderer"));
}

void TilingRenderPolicyST::SetRenderFn(TRenderFn const & renderFn)
{
  graphics::PacketsQueue ** queues = new graphics::PacketsQueue*[m_cpuCoresCount];

  for (unsigned i = 0; i < m_cpuCoresCount; ++i)
    queues[i] = m_QueuedRenderer->GetPacketsQueue(i);

  m_TileRenderer.reset(new TileRenderer(TileSize(),
                                        m_cpuCoresCount,
                                        m_bgColors,
                                        renderFn,
                                        m_primaryRC,
                                        m_resourceManager,
                                        VisualScale(),
                                        queues));

  delete [] queues;

  /// CoverageGenerator rendering queue could execute commands partially
  /// as there are no render-to-texture calls.
//  m_QueuedRenderer->SetPartialExecution(m_cpuCoresCount, true);
  m_CoverageGenerator.reset(new CoverageGenerator(m_TileRenderer.get(),
                                                  m_windowHandle,
                                                  m_primaryRC,
                                                  m_resourceManager,
                                                  m_QueuedRenderer->GetPacketsQueue(m_cpuCoresCount)));
}
