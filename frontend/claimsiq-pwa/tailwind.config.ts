import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./app/**/*.{ts,tsx}",
    "./components/**/*.{ts,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        claimsiq: {
          blue: "#1E40AF",
          "blue-light": "#3B82F6",
          "blue-dark": "#1E3A8A",
        },
      },
    },
  },
  plugins: [],
};

export default config;
