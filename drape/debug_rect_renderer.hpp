#pragma once

#include "drape/gpu_program_manager.hpp"
#include "drape/pointers.hpp"

#include "geometry/rect2d.hpp"
#include "geometry/screenbase.hpp"

#ifdef BUILD_DESIGNER
#define RENDER_DEBUG_RECTS
#endif // BUILD_DESIGNER

namespace dp
{

class DebugRectRenderer
{
public:
  static DebugRectRenderer & Instance();
  void Init(ref_ptr<dp::GpuProgramManager> mng);
  void Destroy();

  bool IsEnabled() const;
  void SetEnabled(bool enabled);

  void DrawRect(ScreenBase const & screen, m2::RectF const & rect);

private:
  DebugRectRenderer();
  ~DebugRectRenderer();

  int m_VAO;
  int m_vertexBuffer;
  ref_ptr<dp::GpuProgram> m_program;
  bool m_isEnabled;
};

} // namespace dp
