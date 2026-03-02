import { createBrowserRouter } from "react-router";
import Login from "./pages/Login";
import Dashboard from "./pages/Dashboard";
import AgencyDashboard from "./pages/AgencyDashboard";
import AgencyUpload from "./pages/AgencyUpload";
import AIProcessing from "./pages/AIProcessing";
import ASMReview from "./pages/ASMReview";
import HQAnalytics from "./pages/HQAnalytics";
import DocumentDetails from "./pages/DocumentDetails";

export const router = createBrowserRouter([
  {
    path: "/",
    Component: Login,
  },
  {
    path: "/dashboard",
    Component: Dashboard,
  },
  {
    path: "/agency/dashboard",
    Component: AgencyDashboard,
  },
  {
    path: "/agency/upload",
    Component: AgencyUpload,
  },
  {
    path: "/ai/processing/:id",
    Component: AIProcessing,
  },
  {
    path: "/asm/review",
    Component: ASMReview,
  },
  {
    path: "/asm/document/:id",
    Component: DocumentDetails,
  },
  {
    path: "/hq/analytics",
    Component: HQAnalytics,
  },
]);