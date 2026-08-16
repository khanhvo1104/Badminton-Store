export type CategoryListItem = {
  id: string;
  parentId: string | null;
  parentName: string | null;
  name: string;
  slug: string;
  description: string | null;
  imagePath: string | null;
  imageUrl: string | null;
  sortOrder: number;
  isActive: boolean;
};

export type CategoryDetail = {
  id: string;
  parentId: string | null;
  name: string;
  slug: string;
  description: string | null;
  imagePath: string | null;
  imageUrl: string | null;
  sortOrder: number;
  isActive: boolean;
};

export type CategoryParentOption = {
  id: string;
  parentId: string | null;
  name: string;
  isActive: boolean;
};

export type CategoryPagination = {
  page: number;
  pageSize: number;
  from: number;
  to: number;
};

export type CategoryListResult = {
  items: CategoryListItem[];
  totalCount: number;
  pagination: CategoryPagination;
  totalPages: number;
};

export type CategoryFormValues = {
  name: string;
  slug: string;
  description: string;
  parentId: string;
  sortOrder: string;
  isActive: boolean;
};

export type CategoryFieldErrors = {
  name?: string;
  slug?: string;
  description?: string;
  parentId?: string;
  sortOrder?: string;
  isActive?: string;
  image?: string;
  confirmed?: string;
  form?: string;
};

export type CategoryFormState = {
  status: "idle" | "error" | "success";
  message: string | null;
  fieldErrors: CategoryFieldErrors;
  values: CategoryFormValues;
};

export type CategoryActivationState = {
  status: "idle" | "error" | "success";
  message: string | null;
  fieldErrors: {
    confirmed?: string;
  };
  isActive: boolean;
};

export type ParsedCategoryInput = {
  name: string;
  slug: string;
  description: string | null;
  parentId: string | null;
  sortOrder: number;
  isActive: boolean;
};
