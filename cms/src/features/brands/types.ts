export type BrandListItem = {
  id: string;
  name: string;
  slug: string;
  description: string | null;
  logoPath: string | null;
  logoUrl: string | null;
  websiteUrl: string | null;
  countryOfOrigin: string | null;
  sortOrder: number;
  isActive: boolean;
};

export type BrandDetail = BrandListItem;

export type BrandPagination = {
  page: number;
  pageSize: number;
  from: number;
  to: number;
};

export type BrandListResult = {
  items: BrandListItem[];
  totalCount: number;
  pagination: BrandPagination;
  totalPages: number;
};

export type BrandFormValues = {
  name: string;
  slug: string;
  description: string;
  websiteUrl: string;
  countryOfOrigin: string;
  sortOrder: string;
  isActive: boolean;
};

export type BrandFieldErrors = {
  name?: string;
  slug?: string;
  description?: string;
  websiteUrl?: string;
  countryOfOrigin?: string;
  sortOrder?: string;
  isActive?: string;
  logo?: string;
  confirmed?: string;
  form?: string;
};

export type BrandFormState = {
  status: "idle" | "error" | "success";
  message: string | null;
  fieldErrors: BrandFieldErrors;
  values: BrandFormValues;
};

export type BrandActivationState = {
  status: "idle" | "error" | "success";
  message: string | null;
  fieldErrors: {
    confirmed?: string;
  };
  isActive: boolean;
};

export type ParsedBrandInput = {
  name: string;
  slug: string;
  description: string | null;
  websiteUrl: string | null;
  countryOfOrigin: string | null;
  sortOrder: number;
  isActive: boolean;
};
