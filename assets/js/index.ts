import { Plugin } from "vite";

/**
 * Vite plugin for integration with the phoenix ecosystem
 *
 * - Make sure vite closes when STDIN is closed to properly when being called as a port.
 *
 * @returns The vite plugin
 */
export function phoenixVitePlugin(): Plugin {
  return {
    name: "phoenix-vite",
    configureServer(_server: any) {
      // make vite correctly detect stdin being closed
      process.stdin.resume();
    },
  };
}
