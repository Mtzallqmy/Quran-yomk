import tokens from './tokens.json';

export interface QuranYutlaBrand {
  name: {
    ar: string;
    en: string;
    code: string;
  };
  tagline: {
    ar: string;
    en: string;
  };
  identifiers: {
    defaultPackageId: string;
    androidAppId: string;
    iosBundleId: string;
    warning: string;
  };
  links: {
    supportEmail: string;
    privacyPolicy: string;
    termsOfService: string;
    githubRepo: string;
  };
}

export interface QuranYutlaColorTokens {
  primary: string;
  primaryDark: string;
  teal: string;
  copper: string;
  pearl: string;
  night: string;
  lightSurface: string;
  darkSurface: string;
  lightSurfaceVariant: string;
  darkSurfaceVariant: string;
  lightTextPrimary: string;
  lightTextSecondary: string;
  darkTextPrimary: string;
  darkTextSecondary: string;
  accentGold: string;
  statusOnline: string;
  statusError: string;
  statusWarning: string;
}

export interface QuranYutlaTypographyTokens {
  arabicUI: string;
  quranText: string;
  latin: string;
  mono: string;
}

export const BRAND: QuranYutlaBrand = tokens.brand;
export const COLORS: QuranYutlaColorTokens = tokens.colors;
export const TYPOGRAPHY: QuranYutlaTypographyTokens = tokens.typography;
export const RADII = tokens.radii;

export default tokens;
