import { ModuleGraph, ModuleNode, Plugin } from "vite";

interface PluginOptions {
  pattern?: RegExp;
}

function invalidateRelatedModules(
  moduleGraph: ModuleGraph,
  modules: ModuleNode[],
  timestamp: number,
): ModuleNode[] {
  const invalidatedModules = new Set<ModuleNode>();

  for (const mod of modules) {
    moduleGraph.invalidateModule(mod, invalidatedModules, timestamp, false);
  }

  return Array.from(invalidatedModules);
}

function buildUpdates(invalidatedModules: ModuleNode[], timestamp: number) {
  return invalidatedModules.flatMap((m) => {
    if (!m.file) return [];

    const updateType = hotUpdateType(m.file);

    if (!updateType) return [];

    return {
      type: updateType,
      path: m.url,
      acceptedPath: m.url,
      timestamp: timestamp,
    };
  });
}

function hotUpdateType(path: string): "css-update" | "js-update" | null {
  if (path.endsWith("css")) return "css-update";
  if (path.endsWith("js")) return "js-update";
  return null;
}

/**
 * Vite plugin for integration with the phoenix ecosystem
 *
 * - Delegate update behaviour for elixir files / templates to phoenix_live_view.
 *
 *   The tailwind vite plugin setup vite level dependencies to elixir files.
 *   Updating those files makes vite do to a full page reload. This plugin
 *   stops that reload, while figuring out if their css or js dependencies might
 *   need reloading (e.g. a class name was added). phoenix_live_reload can then
 *   handle any further behaviour based on elixir files changing.
 *
 * - Make sure vite closes when STDIN is closed to properly when being called as a port.
 *
 * @param opts - Options for the plugin.
 * @returns The vite plugin
 */
export function phoenixVitePlugin(opts: PluginOptions = {}): Plugin {
  return {
    name: "phoenix-vite",
    handleHotUpdate({ file, modules, server, timestamp }) {
      console.log(modules, server.moduleGraph);

      if (!opts.pattern || !file.match(opts.pattern)) return;

      // invalidate all related files so they'll be updated correctly
      const invalidatedModules = invalidateRelatedModules(
        server.moduleGraph,
        modules,
        timestamp,
      );

      // ask client to hot-reload invalidated modules
      server.ws.send({
        type: "update",
        updates: buildUpdates(invalidatedModules, timestamp),
      });

      // delegate the rest to phoenix_live_reload
      return [];
    },
    configureServer(_server: any) {
      // make vite correctly detect stdin being closed
      process.stdin.resume();
    },
  };
}
